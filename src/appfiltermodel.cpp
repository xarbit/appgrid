/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "appfiltermodel.h"

#include <KIO/ApplicationLauncherJob>
#include <KJob>

// Qt 6.13 deprecated invalidateFilter() in favour of begin/endFilterChange().
// Suppress the deprecation warning on older Qt where the replacement doesn't exist.
// APPGRID_INVALIDATE_FILTER  — re-run filter only
// APPGRID_INVALIDATE_ALL     — re-run filter + sort (for search relevance ranking)
#if QT_VERSION >= QT_VERSION_CHECK(6, 13, 0)
#define APPGRID_INVALIDATE_FILTER() do { beginFilterChange(); endFilterChange(); } while (0)
#define APPGRID_INVALIDATE_ALL()    invalidate()
#else
#define APPGRID_INVALIDATE_FILTER() \
    _Pragma("GCC diagnostic push") \
    _Pragma("GCC diagnostic ignored \"-Wdeprecated-declarations\"") \
    invalidateFilter(); \
    _Pragma("GCC diagnostic pop")
#define APPGRID_INVALIDATE_ALL()    invalidate()
#endif

// --- Constructor ---

AppFilterModel::AppFilterModel(QObject *parent)
    : QSortFilterProxyModel(parent)
{
    setSortCaseSensitivity(Qt::CaseInsensitive);
    setFilterCaseSensitivity(Qt::CaseInsensitive);
    sort(0);

    connect(this, &QAbstractItemModel::rowsInserted, this, &AppFilterModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &AppFilterModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &AppFilterModel::countChanged);
    connect(this, &QAbstractItemModel::layoutChanged, this, &AppFilterModel::countChanged);

    // groupedByCategory depends on visible rows — re-emit when filter state changes
    connect(this, &AppFilterModel::hiddenAppsChanged, this, &AppFilterModel::groupedByCategoryChanged);
    connect(this, &AppFilterModel::showFavoritesOnlyChanged, this, &AppFilterModel::groupedByCategoryChanged);
    connect(this, &AppFilterModel::filterCategoryChanged, this, &AppFilterModel::groupedByCategoryChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &AppFilterModel::groupedByCategoryChanged);
}

// --- Property accessors ---

int AppFilterModel::count() const { return rowCount(); }

QString AppFilterModel::filterCategory() const { return m_filterCategory; }

void AppFilterModel::setFilterCategory(const QString &category)
{
    if (m_filterCategory == category)
        return;
    m_filterCategory = category;
    APPGRID_INVALIDATE_FILTER();
    emit filterCategoryChanged();
}

QString AppFilterModel::searchText() const { return m_searchText; }

void AppFilterModel::setSearchText(const QString &text)
{
    if (m_searchText == text)
        return;
    m_searchText = text;
    APPGRID_INVALIDATE_ALL(); // Re-run filter + sort for relevance ranking
    emit searchTextChanged();
}

QStringList AppFilterModel::hiddenApps() const { return m_hiddenApps; }

void AppFilterModel::setHiddenApps(const QStringList &list)
{
    if (m_hiddenApps == list)
        return;
    m_hiddenApps = list;
    APPGRID_INVALIDATE_FILTER();
    emit hiddenAppsChanged();
}

void AppFilterModel::hideApp(int proxyIndex)
{
    const auto idx = index(proxyIndex, 0);
    if (!idx.isValid())
        return;
    const auto sid = idx.data(AppModel::StorageIdRole).toString();
    if (!sid.isEmpty() && !m_hiddenApps.contains(sid)) {
        m_hiddenApps.append(sid);
        APPGRID_INVALIDATE_FILTER();
        emit hiddenAppsChanged();
    }
}

void AppFilterModel::unhideApp(const QString &storageId)
{
    if (m_hiddenApps.contains(storageId)) {
        m_hiddenApps.removeAll(storageId);
        APPGRID_INVALIDATE_FILTER();
        emit hiddenAppsChanged();
    }
}

QStringList AppFilterModel::favoriteApps() const { return m_favoriteApps; }

void AppFilterModel::setFavoriteApps(const QStringList &list)
{
    if (m_favoriteApps == list)
        return;
    m_favoriteApps = list;
    if (m_showFavoritesOnly)
        APPGRID_INVALIDATE_FILTER();
    emit favoriteAppsChanged();
}

bool AppFilterModel::isFavorite(const QString &storageId) const
{
    return m_favoriteApps.contains(storageId);
}

void AppFilterModel::toggleFavorite(const QString &storageId)
{
    if (storageId.isEmpty())
        return;
    if (m_favoriteApps.contains(storageId))
        m_favoriteApps.removeAll(storageId);
    else
        m_favoriteApps.append(storageId);
    if (m_showFavoritesOnly)
        APPGRID_INVALIDATE_FILTER();
    emit favoriteAppsChanged();
}

QStringList AppFilterModel::recentApps() const { return m_recentApps; }

void AppFilterModel::setRecentApps(const QStringList &list)
{
    bool changed = (m_recentApps != list);
    m_recentApps = list;
    invalidate();
    if (changed)
        emit recentAppsChanged();
}

int AppFilterModel::maxRecentApps() const { return m_maxRecentApps; }

void AppFilterModel::setMaxRecentApps(int max)
{
    if (m_maxRecentApps == max)
        return;
    m_maxRecentApps = max;
    emit maxRecentAppsChanged();
}

bool AppFilterModel::isRecent(const QString &storageId) const
{
    return m_recentApps.contains(storageId);
}

int AppFilterModel::sortMode() const { return m_sortMode; }

void AppFilterModel::setSortMode(int mode)
{
    if (m_sortMode == mode)
        return;
    m_sortMode = mode;
    invalidate();
    emit sortModeChanged();
}

QVariantMap AppFilterModel::launchCountsMap() const
{
    QVariantMap map;
    for (auto it = m_launchCounts.cbegin(); it != m_launchCounts.cend(); ++it)
        map.insert(it.key(), it.value());
    return map;
}

void AppFilterModel::setLaunchCountsMap(const QVariantMap &map)
{
    m_launchCounts.clear();
    for (auto it = map.cbegin(); it != map.cend(); ++it)
        m_launchCounts.insert(it.key(), it.value().toInt());
    if (m_sortMode == MostUsed)
        invalidate();
    emit launchCountsChanged();
}

QStringList AppFilterModel::knownApps() const { return m_knownApps; }

void AppFilterModel::setKnownApps(const QStringList &list)
{
    if (m_knownApps == list)
        return;
    m_knownApps = list;
    emit knownAppsChanged();
}

bool AppFilterModel::isNewApp(const QString &storageId) const
{
    return !m_knownApps.isEmpty() && !m_knownApps.contains(storageId);
}

void AppFilterModel::markAllKnown()
{
    auto *model = qobject_cast<AppModel *>(sourceModel());
    if (!model)
        return;
    QStringList all;
    all.reserve(model->rowCount());
    for (int i = 0; i < model->rowCount(); ++i)
        all.append(model->index(i, 0).data(AppModel::StorageIdRole).toString());
    setKnownApps(all);
}

bool AppFilterModel::showFavoritesOnly() const { return m_showFavoritesOnly; }

void AppFilterModel::setShowFavoritesOnly(bool enabled)
{
    if (m_showFavoritesOnly == enabled)
        return;
    m_showFavoritesOnly = enabled;
    APPGRID_INVALIDATE_FILTER();
    emit showFavoritesOnlyChanged();
}

bool AppFilterModel::useSystemCategories() const
{
    auto *src = qobject_cast<AppModel *>(sourceModel());
    return src ? src->useSystemCategories() : false;
}

void AppFilterModel::setUseSystemCategories(bool enabled)
{
    auto *src = qobject_cast<AppModel *>(sourceModel());
    if (src) {
        src->setUseSystemCategories(enabled);
        emit useSystemCategoriesChanged();
        emit categoriesChanged();
    }
}

int AppFilterModel::getLaunchCount(const QString &storageId) const
{
    return m_launchCounts.value(storageId, 0);
}

void AppFilterModel::recordLaunch(const QString &storageId)
{
    if (storageId.isEmpty())
        return;
    m_launchCounts[storageId] = m_launchCounts.value(storageId, 0) + 1;
    emit launchCountsChanged();

    if (!m_knownApps.contains(storageId)) {
        m_knownApps.append(storageId);
        emit knownAppsChanged();
    }
}

// --- Filtering ---

bool AppFilterModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    const auto idx = sourceModel()->index(sourceRow, 0, sourceParent);

    // Hide hidden apps
    const auto sid = idx.data(AppModel::StorageIdRole).toString();
    if (!sid.isEmpty() && m_hiddenApps.contains(sid))
        return false;

    // Favorites-only filter
    if (m_showFavoritesOnly) {
        if (sid.isEmpty() || !m_favoriteApps.contains(sid))
            return false;
    }

    if (!m_filterCategory.isEmpty()) {
        const auto categories = idx.data(AppModel::CategoriesRole).toStringList();
        if (!categories.contains(m_filterCategory))
            return false;
    }

    if (!m_searchText.isEmpty()) {
        const auto name = idx.data(AppModel::NameRole).toString();
        const auto generic = idx.data(AppModel::GenericNameRole).toString();
        bool matched = name.contains(m_searchText, Qt::CaseInsensitive)
                    || generic.contains(m_searchText, Qt::CaseInsensitive);

        // Check desktop file keywords (e.g. "browser" finds Firefox)
        if (!matched) {
            const auto keywords = idx.data(AppModel::KeywordsRole).toStringList();
            for (const auto &kw : keywords) {
                if (kw.contains(m_searchText, Qt::CaseInsensitive)) {
                    matched = true;
                    break;
                }
            }
        }

        if (!matched)
            return false;
    }

    // In "All" view (no category, no search), hide recents from the main grid
    // (they are shown in the header section instead).
    // Skip when: sorting by most-used, showing favorites, or filtering by category/search.
    if (m_sortMode == Alphabetical && !m_showFavoritesOnly
        && m_filterCategory.isEmpty() && m_searchText.isEmpty()
        && !m_recentApps.isEmpty() && m_recentApps.contains(sid))
        return false;

    return true;
}

// --- Sorting ---

// Search relevance: lower score = better match.
// 0 = name prefix, 1 = name substring, 2 = generic name, 3 = keyword, 4 = no match.
static int searchRelevance(const QModelIndex &idx, const QString &query)
{
    if (query.isEmpty())
        return 4;

    const auto name = idx.data(AppModel::NameRole).toString();
    if (name.startsWith(query, Qt::CaseInsensitive))
        return 0;
    if (name.contains(query, Qt::CaseInsensitive))
        return 1;

    const auto generic = idx.data(AppModel::GenericNameRole).toString();
    if (generic.contains(query, Qt::CaseInsensitive))
        return 2;

    const auto keywords = idx.data(AppModel::KeywordsRole).toStringList();
    for (const auto &kw : keywords) {
        if (kw.contains(query, Qt::CaseInsensitive))
            return 3;
    }

    return 4;
}

bool AppFilterModel::lessThan(const QModelIndex &left, const QModelIndex &right) const
{
    // In favorites mode, sort by position in favoriteApps list
    if (m_showFavoritesOnly) {
        const auto leftSid = left.data(AppModel::StorageIdRole).toString();
        const auto rightSid = right.data(AppModel::StorageIdRole).toString();
        return m_favoriteApps.indexOf(leftSid) < m_favoriteApps.indexOf(rightSid);
    }

    // When searching, rank by match relevance first
    if (!m_searchText.isEmpty()) {
        const int leftRel = searchRelevance(left, m_searchText);
        const int rightRel = searchRelevance(right, m_searchText);
        if (leftRel != rightRel)
            return leftRel < rightRel;

        // Within the same relevance tier, prefer more frequently launched apps
        const auto leftSid = left.data(AppModel::StorageIdRole).toString();
        const auto rightSid = right.data(AppModel::StorageIdRole).toString();
        const int leftCount = m_launchCounts.value(leftSid, 0);
        const int rightCount = m_launchCounts.value(rightSid, 0);
        if (leftCount != rightCount)
            return leftCount > rightCount;
    } else if (m_sortMode == MostUsed) {
        const auto leftSid = left.data(AppModel::StorageIdRole).toString();
        const auto rightSid = right.data(AppModel::StorageIdRole).toString();
        const int leftCount = m_launchCounts.value(leftSid, 0);
        const int rightCount = m_launchCounts.value(rightSid, 0);
        if (leftCount != rightCount)
            return leftCount > rightCount;
    } else if (m_sortMode == ByCategory) {
        const auto leftCat = left.data(AppModel::CategoryRole).toString();
        const auto rightCat = right.data(AppModel::CategoryRole).toString();
        int cmp = QString::localeAwareCompare(leftCat, rightCat);
        if (cmp != 0)
            return cmp < 0;
    }

    const auto leftName = left.data(AppModel::NameRole).toString();
    const auto rightName = right.data(AppModel::NameRole).toString();
    return QString::localeAwareCompare(leftName, rightName) < 0;
}

// --- Category queries ---

QVariantList AppFilterModel::appsByCategory() const
{
    QMap<QString, QVariantList> catMap;
    for (int i = 0; i < rowCount(); ++i) {
        const auto idx = index(i, 0);
        const auto cats = idx.data(AppModel::CategoriesRole).toStringList();

        QVariantMap app;
        app[QStringLiteral("name")] = idx.data(AppModel::NameRole);
        app[QStringLiteral("iconName")] = idx.data(AppModel::IconRole);
        app[QStringLiteral("storageId")] = idx.data(AppModel::StorageIdRole);
        app[QStringLiteral("desktopFile")] = idx.data(AppModel::DesktopFileRole);
        app[QStringLiteral("proxyIndex")] = i;

        for (const auto &cat : cats)
            catMap[cat].append(app);
    }

    QVariantList result;
    for (auto it = catMap.constBegin(); it != catMap.constEnd(); ++it) {
        QVariantMap section;
        section[QStringLiteral("category")] = it.key();
        section[QStringLiteral("apps")] = it.value();
        result.append(section);
    }
    return result;
}

QStringList AppFilterModel::nonEmptyCategories() const
{
    auto *src = sourceModel();
    if (!src)
        return {};

    QSet<QString> cats;
    for (int i = 0; i < src->rowCount(); ++i) {
        const auto idx = src->index(i, 0);
        const auto sid = idx.data(AppModel::StorageIdRole).toString();
        if (!sid.isEmpty() && m_hiddenApps.contains(sid))
            continue;
        const auto appCats = idx.data(AppModel::CategoriesRole).toStringList();
        for (const auto &c : appCats)
            cats.insert(c);
    }
    return cats.values();
}

QStringList AppFilterModel::categories() const
{
    auto *model = qobject_cast<AppModel *>(sourceModel());
    return model ? model->categories() : QStringList();
}

QString AppFilterModel::categoryMenuPath(const QString &category) const
{
    auto *model = qobject_cast<AppModel *>(sourceModel());
    return model ? model->categoryMenuPath(category) : QString();
}

QVariantMap AppFilterModel::getByStorageId(const QString &storageId) const
{
    QVariantMap map;
    auto *src = sourceModel();
    if (!src)
        return map;
    for (int i = 0; i < src->rowCount(); ++i) {
        const auto idx = src->index(i, 0);
        if (idx.data(AppModel::StorageIdRole).toString() == storageId) {
            map[QStringLiteral("name")] = idx.data(AppModel::NameRole);
            map[QStringLiteral("iconName")] = idx.data(AppModel::IconRole);
            map[QStringLiteral("desktopFile")] = idx.data(AppModel::DesktopFileRole);
            map[QStringLiteral("storageId")] = idx.data(AppModel::StorageIdRole);
            map[QStringLiteral("genericName")] = idx.data(AppModel::GenericNameRole);
            break;
        }
    }
    return map;
}

QVariantMap AppFilterModel::get(int proxyRow) const
{
    QVariantMap map;
    const auto idx = index(proxyRow, 0);
    if (!idx.isValid())
        return map;
    const auto roles = roleNames();
    for (auto it = roles.cbegin(); it != roles.cend(); ++it)
        map.insert(QString::fromUtf8(it.value()), idx.data(it.key()));
    return map;
}

// --- Favorites reordering ---

void AppFilterModel::moveFavorite(const QString &storageId, int toIndex)
{
    if (!m_favoriteApps.contains(storageId))
        return;
    m_favoriteApps.removeAll(storageId);
    if (toIndex < 0) toIndex = 0;
    if (toIndex > m_favoriteApps.size()) toIndex = m_favoriteApps.size();
    m_favoriteApps.insert(toIndex, storageId);
    invalidate();
    emit favoriteAppsChanged();
}

// --- Launching ---

void AppFilterModel::launch(int proxyIndex)
{
    const auto idx = index(proxyIndex, 0);
    const auto sourceIdx = mapToSource(idx);
    auto *model = qobject_cast<AppModel *>(sourceModel());
    if (!model)
        return;

    const auto sid = idx.data(AppModel::StorageIdRole).toString();
    if (!sid.isEmpty()) {
        m_recentApps.removeAll(sid);
        m_recentApps.prepend(sid);
        while (m_recentApps.size() > m_maxRecentApps)
            m_recentApps.removeLast();
        invalidate();
        emit recentAppsChanged();
        recordLaunch(sid);
    }

    model->launch(sourceIdx.row());
}

void AppFilterModel::launchByStorageId(const QString &storageId)
{
    auto *model = qobject_cast<AppModel *>(sourceModel());
    if (!model)
        return;

    for (int i = 0; i < model->rowCount(); ++i) {
        const auto idx = model->index(i, 0);
        if (idx.data(AppModel::StorageIdRole).toString() == storageId) {
            m_recentApps.removeAll(storageId);
            m_recentApps.prepend(storageId);
            while (m_recentApps.size() > m_maxRecentApps)
                m_recentApps.removeLast();
            invalidate();
            emit recentAppsChanged();
            recordLaunch(storageId);

            model->launch(i);
            return;
        }
    }
}
