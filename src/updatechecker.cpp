/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "updatechecker.h"

#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QSysInfo>
#include <QUrl>

namespace {
// Static JSON endpoint on the AppGrid website. Served from GitHub Pages CDN
// so there are no GitHub API rate-limit concerns. Updated automatically by
// the website's build pipeline on each AppGrid release (repository_dispatch).
// QLatin1StringView keeps this a compile-time literal with no runtime alloc.
constexpr auto kManifestUrl = QLatin1StringView(
    "https://appgrid.xarbit.dev/api/latest.json");

// Re-check interval while enabled. Long-running sessions still pick up new
// releases without needing a Plasma restart.
constexpr int kPeriodicCheckMs = 24 * 60 * 60 * 1000;

// Hard cap on response size. The endpoint serves a few hundred bytes; this
// is generous headroom so the periodic check can never be turned into a
// memory-exhaustion vector by a misbehaving or compromised server.
constexpr qint64 kMaxResponseBytes = 16 * 1024;
} // namespace

// On-disk state lives in the per-user cache dir so it never bloats config.
static QString stateFilePath()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    return dir + QStringLiteral("/update-checker.json");
}

UpdateChecker::UpdateChecker(const QString &currentVersion, QObject *parent)
    : QObject(parent)
    , m_currentVersion(currentVersion)
{
    loadState();
    m_periodicTimer.setInterval(kPeriodicCheckMs);
    connect(&m_periodicTimer, &QTimer::timeout, this, [this]() {
        runCheck(/*force=*/false);
    });
    // We don't auto-fire on construction — the QML side flips `enabled`
    // when the config is on, and that triggers the first check.
}

UpdateChecker::~UpdateChecker() = default;

void UpdateChecker::setEnabled(bool enabled)
{
    if (m_enabled == enabled)
        return;
    m_enabled = enabled;
    emit enabledChanged();
    if (enabled) {
        // Immediate check on enable so the indicator reflects reality,
        // not whatever the cache file said at construction. Async, never
        // blocks the UI thread.
        runCheck(/*force=*/true);
        // Long-running sessions keep getting updates via the periodic timer.
        m_periodicTimer.start();
    } else {
        m_periodicTimer.stop();
    }
}

void UpdateChecker::checkNow()
{
    runCheck(/*force=*/true);
}

void UpdateChecker::openReleasePage()
{
    if (m_releaseUrl.isEmpty())
        return;
    // Only open well-formed http(s) URLs. The release URL comes from a JSON
    // endpoint we own, but treat it as untrusted input: a server compromise
    // shouldn't be able to redirect a click into `file://`, `mailto:`, or
    // any other scheme QDesktopServices is willing to dispatch.
    const QUrl url(m_releaseUrl);
    if (!url.isValid())
        return;
    const QString scheme = url.scheme().toLower();
    if (scheme != QStringLiteral("http") && scheme != QStringLiteral("https")) {
        qWarning("AppGrid update check: refusing release URL with scheme %s",
                 qPrintable(scheme));
        return;
    }
    QDesktopServices::openUrl(url);
}

void UpdateChecker::runCheck(bool force)
{
    if (!force && !m_enabled)
        return;

    if (!m_network)
        m_network = new QNetworkAccessManager(this);

    QNetworkRequest req{QUrl(kManifestUrl)};
    req.setHeader(QNetworkRequest::UserAgentHeader,
                  QStringLiteral("AppGrid/%1 (universal)").arg(m_currentVersion));
    // ETag caching keeps unchanged responses to a 304 with no body. Saves
    // bandwidth on the CDN side and on the user's connection.
    if (!m_etag.isEmpty())
        req.setRawHeader("If-None-Match", m_etag.toUtf8());

    QNetworkReply *reply = m_network->get(req);
    // Cap response size. The endpoint serves ~200 bytes; 16 KiB is generous
    // headroom for future fields without giving a misbehaving server room to
    // stream arbitrarily large payloads into the plasmoid process. We catch
    // both an over-large Content-Length up front (metaDataChanged) and a
    // server that streams more bytes than it advertised (downloadProgress).
    connect(reply, &QNetworkReply::metaDataChanged, this, [reply]() {
        const auto cl = reply->header(QNetworkRequest::ContentLengthHeader);
        if (cl.isValid() && cl.toLongLong() > kMaxResponseBytes) {
            qWarning("AppGrid update check: Content-Length %lld exceeds cap, aborting",
                     cl.toLongLong());
            reply->abort();
        }
    });
    connect(reply, &QNetworkReply::downloadProgress, this,
            [reply](qint64 bytesReceived, qint64 /*bytesTotal*/) {
        if (bytesReceived > kMaxResponseBytes) {
            qWarning("AppGrid update check: response exceeded %lld bytes, aborting",
                     static_cast<long long>(kMaxResponseBytes));
            reply->abort();
        }
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply]() { handleReply(reply); });
}

void UpdateChecker::handleReply(QNetworkReply *reply)
{
    reply->deleteLater();
    m_lastCheck = QDateTime::currentDateTimeUtc();

    // Capture ETag for next request even on errors — server may have set one.
    const QByteArray etag = reply->rawHeader("ETag");
    if (!etag.isEmpty())
        m_etag = QString::fromLatin1(etag);

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    if (status == 304) {
        // Cached version is current; nothing changed since last check.
        saveState();
        return;
    }

    if (reply->error() != QNetworkReply::NoError || status != 200) {
        // Soft failure — leave state alone, retry on next throttle window.
        qWarning("AppGrid update check: %s (HTTP %d)",
                 qPrintable(reply->errorString()), status);
        saveState();
        return;
    }

    QJsonParseError err{};
    const auto doc = QJsonDocument::fromJson(reply->readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning("AppGrid update check: malformed JSON");
        saveState();
        return;
    }

    const auto obj = doc.object();
    const auto version = obj.value(QStringLiteral("version")).toString();
    const auto releaseUrl = obj.value(QStringLiteral("release_notes_url")).toString();

    if (version.isEmpty()) {
        saveState();
        return;
    }

    const bool wasAvailable = m_hasUpdate;
    const QString prevVersion = m_latestVersion;
    const QString prevUrl = m_releaseUrl;

    m_latestVersion = version;
    m_releaseUrl = releaseUrl;
    m_hasUpdate = isNewer(version, m_currentVersion);

    if (m_latestVersion != prevVersion) emit latestVersionChanged();
    if (m_releaseUrl != prevUrl) emit releaseUrlChanged();
    if (m_hasUpdate != wasAvailable) emit hasUpdateChanged();

    saveState();
}

void UpdateChecker::loadState()
{
    QFile f(stateFilePath());
    if (!f.open(QIODevice::ReadOnly))
        return;
    const auto doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject())
        return;
    const auto obj = doc.object();
    m_latestVersion = obj.value(QStringLiteral("latestVersion")).toString();
    m_releaseUrl    = obj.value(QStringLiteral("releaseUrl")).toString();
    m_etag          = obj.value(QStringLiteral("etag")).toString();
    m_lastCheck     = QDateTime::fromString(
        obj.value(QStringLiteral("lastCheck")).toString(), Qt::ISODate);
    m_hasUpdate     = !m_latestVersion.isEmpty()
        && isNewer(m_latestVersion, m_currentVersion);
}

void UpdateChecker::saveState()
{
    QFile f(stateFilePath());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        // Cache dir may not exist yet — try to create it once.
        QDir().mkpath(QFileInfo(f).absolutePath());
        if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
            return;
    }
    QJsonObject obj{
        {QStringLiteral("latestVersion"), m_latestVersion},
        {QStringLiteral("releaseUrl"), m_releaseUrl},
        {QStringLiteral("etag"), m_etag},
        {QStringLiteral("lastCheck"), m_lastCheck.toString(Qt::ISODate)},
    };
    f.write(QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

bool UpdateChecker::isNewer(const QString &candidate, const QString &current)
{
    // Strip a leading 'v' if present (release tags: v1.8.1 vs 1.8.1).
    auto strip = [](const QString &s) {
        return s.startsWith(QLatin1Char('v')) ? s.mid(1) : s;
    };
    const auto a = strip(candidate);
    const auto b = strip(current);

    // Numeric segment compare (1.10.0 > 1.9.9). Non-numeric parts compared as
    // strings, which is enough for stable + simple pre-release strings; if we
    // ever ship complex pre-releases we'll need a proper semver parser.
    const auto pa = a.split(QRegularExpression(QStringLiteral("[.\\-+]")));
    const auto pb = b.split(QRegularExpression(QStringLiteral("[.\\-+]")));
    const int n = qMax(pa.size(), pb.size());
    for (int i = 0; i < n; ++i) {
        const auto sa = i < pa.size() ? pa[i] : QStringLiteral("0");
        const auto sb = i < pb.size() ? pb[i] : QStringLiteral("0");
        bool na = false, nb = false;
        const int ia = sa.toInt(&na);
        const int ib = sb.toInt(&nb);
        if (na && nb) {
            if (ia != ib) return ia > ib;
        } else {
            const int cmp = QString::compare(sa, sb);
            if (cmp != 0) return cmp > 0;
        }
    }
    return false; // equal
}
