#include "appmodel.h"

#include <KService>
#include <KServiceGroup>

#include <KIO/ApplicationLauncherJob>

#include <QCollator>
#include <algorithm>

// Map freedesktop categories to user-friendly groups
static const QHash<QString, QString> &categoryMap()
{
    static const QHash<QString, QString> map = {
        // Utilities
        {QStringLiteral("Utility"), QStringLiteral("Utilities")},
        {QStringLiteral("Accessibility"), QStringLiteral("Utilities")},
        {QStringLiteral("Core"), QStringLiteral("Utilities")},
        {QStringLiteral("Legacy"), QStringLiteral("Utilities")},
        {QStringLiteral("TextEditor"), QStringLiteral("Utilities")},
        {QStringLiteral("Archiving"), QStringLiteral("Utilities")},
        {QStringLiteral("Compression"), QStringLiteral("Utilities")},
        {QStringLiteral("FileManager"), QStringLiteral("Utilities")},
        {QStringLiteral("TerminalEmulator"), QStringLiteral("Utilities")},
        {QStringLiteral("FileTools"), QStringLiteral("Utilities")},
        {QStringLiteral("Filesystem"), QStringLiteral("Utilities")},
        // Development
        {QStringLiteral("Development"), QStringLiteral("Development")},
        {QStringLiteral("IDE"), QStringLiteral("Development")},
        {QStringLiteral("Debugger"), QStringLiteral("Development")},
        {QStringLiteral("RevisionControl"), QStringLiteral("Development")},
        {QStringLiteral("WebDevelopment"), QStringLiteral("Development")},
        {QStringLiteral("Building"), QStringLiteral("Development")},
        // Graphics
        {QStringLiteral("Graphics"), QStringLiteral("Graphics")},
        {QStringLiteral("2DGraphics"), QStringLiteral("Graphics")},
        {QStringLiteral("3DGraphics"), QStringLiteral("Graphics")},
        {QStringLiteral("RasterGraphics"), QStringLiteral("Graphics")},
        {QStringLiteral("VectorGraphics"), QStringLiteral("Graphics")},
        {QStringLiteral("Photography"), QStringLiteral("Graphics")},
        {QStringLiteral("ImageProcessing"), QStringLiteral("Graphics")},
        {QStringLiteral("Scanning"), QStringLiteral("Graphics")},
        // Internet
        {QStringLiteral("Network"), QStringLiteral("Internet")},
        {QStringLiteral("WebBrowser"), QStringLiteral("Internet")},
        {QStringLiteral("Email"), QStringLiteral("Internet")},
        {QStringLiteral("Chat"), QStringLiteral("Internet")},
        {QStringLiteral("InstantMessaging"), QStringLiteral("Internet")},
        {QStringLiteral("IRCClient"), QStringLiteral("Internet")},
        {QStringLiteral("FileTransfer"), QStringLiteral("Internet")},
        {QStringLiteral("P2P"), QStringLiteral("Internet")},
        {QStringLiteral("RemoteAccess"), QStringLiteral("Internet")},
        {QStringLiteral("News"), QStringLiteral("Internet")},
        // Multimedia
        {QStringLiteral("AudioVideo"), QStringLiteral("Multimedia")},
        {QStringLiteral("Audio"), QStringLiteral("Multimedia")},
        {QStringLiteral("Video"), QStringLiteral("Multimedia")},
        {QStringLiteral("Music"), QStringLiteral("Multimedia")},
        {QStringLiteral("Player"), QStringLiteral("Multimedia")},
        {QStringLiteral("Recorder"), QStringLiteral("Multimedia")},
        {QStringLiteral("Midi"), QStringLiteral("Multimedia")},
        {QStringLiteral("Mixer"), QStringLiteral("Multimedia")},
        {QStringLiteral("Sequencer"), QStringLiteral("Multimedia")},
        // Office
        {QStringLiteral("Office"), QStringLiteral("Office")},
        {QStringLiteral("Calendar"), QStringLiteral("Office")},
        {QStringLiteral("ContactManagement"), QStringLiteral("Office")},
        {QStringLiteral("Database"), QStringLiteral("Office")},
        {QStringLiteral("Dictionary"), QStringLiteral("Office")},
        {QStringLiteral("Finance"), QStringLiteral("Office")},
        {QStringLiteral("Presentation"), QStringLiteral("Office")},
        {QStringLiteral("ProjectManagement"), QStringLiteral("Office")},
        {QStringLiteral("Spreadsheet"), QStringLiteral("Office")},
        {QStringLiteral("WordProcessor"), QStringLiteral("Office")},
        // Games
        {QStringLiteral("Game"), QStringLiteral("Games")},
        {QStringLiteral("ActionGame"), QStringLiteral("Games")},
        {QStringLiteral("AdventureGame"), QStringLiteral("Games")},
        {QStringLiteral("ArcadeGame"), QStringLiteral("Games")},
        {QStringLiteral("BoardGame"), QStringLiteral("Games")},
        {QStringLiteral("BlocksGame"), QStringLiteral("Games")},
        {QStringLiteral("CardGame"), QStringLiteral("Games")},
        {QStringLiteral("LogicGame"), QStringLiteral("Games")},
        {QStringLiteral("Simulation"), QStringLiteral("Games")},
        {QStringLiteral("SportsGame"), QStringLiteral("Games")},
        {QStringLiteral("StrategyGame"), QStringLiteral("Games")},
        // Education & Science
        {QStringLiteral("Education"), QStringLiteral("Education")},
        {QStringLiteral("Science"), QStringLiteral("Education")},
        {QStringLiteral("Math"), QStringLiteral("Education")},
        {QStringLiteral("Astronomy"), QStringLiteral("Education")},
        {QStringLiteral("Chemistry"), QStringLiteral("Education")},
        {QStringLiteral("Geography"), QStringLiteral("Education")},
        {QStringLiteral("Languages"), QStringLiteral("Education")},
        // System
        {QStringLiteral("System"), QStringLiteral("System")},
        {QStringLiteral("Settings"), QStringLiteral("System")},
        {QStringLiteral("Monitor"), QStringLiteral("System")},
        {QStringLiteral("Security"), QStringLiteral("System")},
        {QStringLiteral("PackageManager"), QStringLiteral("System")},
        {QStringLiteral("HardwareSettings"), QStringLiteral("System")},
        {QStringLiteral("Printing"), QStringLiteral("System")},
    };
    return map;
}

AppModel::AppModel(QObject *parent)
    : QAbstractListModel(parent)
{
    loadApplications();
}

int AppModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_apps.size();
}

QVariant AppModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_apps.size())
        return {};

    const auto &app = m_apps[index.row()];
    switch (role) {
    case NameRole:
        return app.name;
    case IconRole:
        return app.icon;
    case DesktopFileRole:
        return app.desktopFile;
    case CategoryRole:
        return app.category;
    case GenericNameRole:
        return app.genericName;
    }
    return {};
}

QHash<int, QByteArray> AppModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {IconRole, "iconName"},
        {DesktopFileRole, "desktopFile"},
        {CategoryRole, "category"},
        {GenericNameRole, "genericName"},
    };
}

QString AppModel::mapCategory(const QStringList &categories) const
{
    const auto &map = categoryMap();
    for (const auto &cat : categories) {
        auto it = map.find(cat);
        if (it != map.end())
            return it.value();
    }
    return QStringLiteral("Other");
}

void AppModel::loadApplications()
{
    const auto services = KService::allServices();
    QSet<QString> seen;
    QSet<QString> categorySet;

    for (const auto &service : services) {
        if (service->noDisplay() || service->exec().isEmpty())
            continue;

        const QString name = service->name();
        if (name.isEmpty() || seen.contains(name))
            continue;
        seen.insert(name);

        AppEntry entry;
        entry.name = name;
        entry.icon = service->icon();
        entry.desktopFile = service->entryPath();
        entry.genericName = service->genericName();
        entry.exec = service->exec();
        entry.category = mapCategory(service->categories());

        categorySet.insert(entry.category);
        m_apps.append(entry);
    }

    // Sort alphabetically
    QCollator collator;
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(m_apps.begin(), m_apps.end(), [&collator](const AppEntry &a, const AppEntry &b) {
        return collator.compare(a.name, b.name) < 0;
    });

    m_categories = categorySet.values();
    m_categories.sort();
}

void AppModel::launch(int index)
{
    if (index < 0 || index >= m_apps.size())
        return;

    const auto &app = m_apps[index];
    auto service = KService::serviceByDesktopPath(app.desktopFile);
    if (!service)
        service = KService::serviceByDesktopName(app.desktopFile);
    if (!service)
        return;

    auto *job = new KIO::ApplicationLauncherJob(service);
    job->start();
}

QStringList AppModel::categories() const
{
    return m_categories;
}

// --- AppFilterModel ---

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
}

int AppFilterModel::count() const
{
    return rowCount();
}

QString AppFilterModel::filterCategory() const
{
    return m_filterCategory;
}

void AppFilterModel::setFilterCategory(const QString &category)
{
    if (m_filterCategory == category)
        return;
    beginFilterChange();
    m_filterCategory = category;
    endFilterChange();
    emit filterCategoryChanged();
}

QString AppFilterModel::searchText() const
{
    return m_searchText;
}

void AppFilterModel::setSearchText(const QString &text)
{
    if (m_searchText == text)
        return;
    beginFilterChange();
    m_searchText = text;
    endFilterChange();
    emit searchTextChanged();
}

bool AppFilterModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    const auto idx = sourceModel()->index(sourceRow, 0, sourceParent);

    if (!m_filterCategory.isEmpty()) {
        const auto category = idx.data(AppModel::CategoryRole).toString();
        if (category != m_filterCategory)
            return false;
    }

    if (!m_searchText.isEmpty()) {
        const auto name = idx.data(AppModel::NameRole).toString();
        const auto generic = idx.data(AppModel::GenericNameRole).toString();
        if (!name.contains(m_searchText, Qt::CaseInsensitive)
            && !generic.contains(m_searchText, Qt::CaseInsensitive))
            return false;
    }

    return true;
}

bool AppFilterModel::lessThan(const QModelIndex &left, const QModelIndex &right) const
{
    const auto leftName = left.data(AppModel::NameRole).toString();
    const auto rightName = right.data(AppModel::NameRole).toString();
    return QString::localeAwareCompare(leftName, rightName) < 0;
}

void AppFilterModel::launch(int proxyIndex)
{
    const auto sourceIdx = mapToSource(index(proxyIndex, 0));
    auto *model = qobject_cast<AppModel *>(sourceModel());
    if (model)
        model->launch(sourceIdx.row());
}

QStringList AppFilterModel::categories() const
{
    auto *model = qobject_cast<AppModel *>(sourceModel());
    return model ? model->categories() : QStringList();
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
