/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Smoke tests for AppFilterModel: property accessors, signal emission,
    round-trip of list-typed properties.
*/

#include <QSignalSpy>
#include <QTest>

#include "appfiltermodel.h"
#include "stubappmodel.h"

class TestAppFilterModel : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void init();
    void searchTextEmitsSignalOnceOnChange();
    void sortModeChangeEmitsSignal();
    void favoritesToggleRoundtrip();
    void hiddenAppsRoundtrip();
    void launchCountsMapRoundtrip();
    void maxRecentAppsSetterEmitsSignal();
    void moveFavoriteReordersList();
    void moveFavoriteClampsOutOfRange();
    void moveFavoriteIgnoresUnknownId();
    void isNewAppReturnsFalseWhenKnownEmpty();
    void isNewAppReturnsTrueForUnknown();
    void getByStorageIdReturnsMatchingMap();
    void getByStorageIdReturnsEmptyWhenMissing();
    void getReturnsEmptyForInvalidRow();
    void nonEmptyCategoriesSkipsHiddenApps();
    void appsByCategoryGroupsMultiCategoryApp();
    void countSignalEmitsOnSourceChange();

private:
    StubAppModel m_source;
    AppFilterModel m_filter;
};

void TestAppFilterModel::initTestCase()
{
    m_filter.setSourceModel(&m_source);
}

void TestAppFilterModel::init()
{
    m_source.setApps({});
    m_filter.setSearchText(QString());
    m_filter.setFilterCategory(QString());
    m_filter.setHiddenApps({});
    m_filter.setFavoriteApps({});
    m_filter.setRecentApps({});
    m_filter.setShowFavoritesOnly(false);
    m_filter.setSortMode(AppFilterModel::Alphabetical);
    m_filter.setLaunchCountsMap({});
    m_filter.setKnownApps({});
}

void TestAppFilterModel::searchTextEmitsSignalOnceOnChange()
{
    QSignalSpy spy(&m_filter, &AppFilterModel::searchTextChanged);
    m_filter.setSearchText(QStringLiteral("firefox"));
    QCOMPARE(spy.count(), 1);
    QCOMPARE(m_filter.searchText(), QStringLiteral("firefox"));

    m_filter.setSearchText(QStringLiteral("firefox"));
    QCOMPARE(spy.count(), 1); // no signal when unchanged
}

void TestAppFilterModel::sortModeChangeEmitsSignal()
{
    QSignalSpy spy(&m_filter, &AppFilterModel::sortModeChanged);
    m_filter.setSortMode(AppFilterModel::MostUsed);
    QCOMPARE(spy.count(), 1);
    QCOMPARE(m_filter.sortMode(), int(AppFilterModel::MostUsed));

    m_filter.setSortMode(AppFilterModel::ByCategory);
    QCOMPARE(spy.count(), 2);
}

void TestAppFilterModel::favoritesToggleRoundtrip()
{
    const QString id = QStringLiteral("test.desktop");
    QVERIFY(!m_filter.isFavorite(id));
    m_filter.setFavoriteApps({id});
    QVERIFY(m_filter.isFavorite(id));
    QCOMPARE(m_filter.favoriteApps(), QStringList{id});
}

void TestAppFilterModel::hiddenAppsRoundtrip()
{
    const QStringList ids = {QStringLiteral("a.desktop"), QStringLiteral("b.desktop")};
    QSignalSpy spy(&m_filter, &AppFilterModel::hiddenAppsChanged);
    m_filter.setHiddenApps(ids);
    QCOMPARE(spy.count(), 1);
    QCOMPARE(m_filter.hiddenApps(), ids);
}

void TestAppFilterModel::launchCountsMapRoundtrip()
{
    QVariantMap in;
    in[QStringLiteral("a")] = 5;
    in[QStringLiteral("b")] = 12;
    m_filter.setLaunchCountsMap(in);
    QCOMPARE(m_filter.getLaunchCount(QStringLiteral("a")), 5);
    QCOMPARE(m_filter.getLaunchCount(QStringLiteral("b")), 12);
    QCOMPARE(m_filter.getLaunchCount(QStringLiteral("missing")), 0);
}

void TestAppFilterModel::maxRecentAppsSetterEmitsSignal()
{
    QSignalSpy spy(&m_filter, &AppFilterModel::maxRecentAppsChanged);
    m_filter.setMaxRecentApps(10);
    QCOMPARE(spy.count(), 1);
    QCOMPARE(m_filter.maxRecentApps(), 10);
    m_filter.setMaxRecentApps(10);
    QCOMPARE(spy.count(), 1); // no signal when unchanged
}

void TestAppFilterModel::moveFavoriteReordersList()
{
    m_filter.setFavoriteApps({QStringLiteral("a"), QStringLiteral("b"), QStringLiteral("c")});
    m_filter.moveFavorite(QStringLiteral("c"), 0);
    QCOMPARE(m_filter.favoriteApps(), (QStringList{
        QStringLiteral("c"), QStringLiteral("a"), QStringLiteral("b")}));
}

void TestAppFilterModel::moveFavoriteClampsOutOfRange()
{
    m_filter.setFavoriteApps({QStringLiteral("a"), QStringLiteral("b"), QStringLiteral("c")});
    m_filter.moveFavorite(QStringLiteral("a"), -5);
    QCOMPARE(m_filter.favoriteApps().first(), QStringLiteral("a"));

    m_filter.moveFavorite(QStringLiteral("a"), 999);
    QCOMPARE(m_filter.favoriteApps().last(), QStringLiteral("a"));
}

void TestAppFilterModel::moveFavoriteIgnoresUnknownId()
{
    const QStringList before{QStringLiteral("a"), QStringLiteral("b")};
    m_filter.setFavoriteApps(before);
    m_filter.moveFavorite(QStringLiteral("ghost"), 0);
    QCOMPARE(m_filter.favoriteApps(), before);
}

void TestAppFilterModel::isNewAppReturnsFalseWhenKnownEmpty()
{
    QVERIFY(m_filter.knownApps().isEmpty());
    QVERIFY(!m_filter.isNewApp(QStringLiteral("anything")));
}

void TestAppFilterModel::isNewAppReturnsTrueForUnknown()
{
    m_filter.setKnownApps({QStringLiteral("a"), QStringLiteral("b")});
    QVERIFY(!m_filter.isNewApp(QStringLiteral("a")));
    QVERIFY(m_filter.isNewApp(QStringLiteral("c")));
}

void TestAppFilterModel::getByStorageIdReturnsMatchingMap()
{
    m_source.setApps({
        {QStringLiteral("Kate"), QStringLiteral("kate-icon"), QStringLiteral("/x/kate.desktop"),
         {QStringLiteral("Development")}, QStringLiteral("Editor"), QStringLiteral("kate"),
         {}, QStringLiteral("Text editor"), QStringLiteral("System")},
    });
    const auto map = m_filter.getByStorageId(QStringLiteral("kate"));
    QCOMPARE(map.value(QStringLiteral("name")).toString(), QStringLiteral("Kate"));
    QCOMPARE(map.value(QStringLiteral("iconName")).toString(), QStringLiteral("kate-icon"));
    QCOMPARE(map.value(QStringLiteral("storageId")).toString(), QStringLiteral("kate"));
}

void TestAppFilterModel::getByStorageIdReturnsEmptyWhenMissing()
{
    m_source.setApps({
        {QStringLiteral("Kate"), {}, {}, {}, {}, QStringLiteral("kate"), {}, {}, {}},
    });
    QVERIFY(m_filter.getByStorageId(QStringLiteral("ghost")).isEmpty());
}

void TestAppFilterModel::getReturnsEmptyForInvalidRow()
{
    QVERIFY(m_filter.get(-1).isEmpty());
    QVERIFY(m_filter.get(9999).isEmpty());
}

void TestAppFilterModel::nonEmptyCategoriesSkipsHiddenApps()
{
    m_source.setApps({
        {QStringLiteral("A"), {}, {}, {QStringLiteral("X")}, {}, QStringLiteral("a"), {}, {}, {}},
        {QStringLiteral("B"), {}, {}, {QStringLiteral("Y")}, {}, QStringLiteral("b"), {}, {}, {}},
    });
    QStringList cats = m_filter.nonEmptyCategories();
    cats.sort();
    QCOMPARE(cats, (QStringList{QStringLiteral("X"), QStringLiteral("Y")}));

    m_filter.setHiddenApps({QStringLiteral("b")});
    cats = m_filter.nonEmptyCategories();
    cats.sort();
    QCOMPARE(cats, QStringList{QStringLiteral("X")});
}

void TestAppFilterModel::appsByCategoryGroupsMultiCategoryApp()
{
    m_source.setApps({
        {QStringLiteral("Multi"), {}, {}, {QStringLiteral("Dev"), QStringLiteral("Util")},
         {}, QStringLiteral("m"), {}, {}, {}},
        {QStringLiteral("Single"), {}, {}, {QStringLiteral("Dev")},
         {}, QStringLiteral("s"), {}, {}, {}},
    });
    const auto groups = m_filter.appsByCategory();
    QCOMPARE(groups.size(), 2);

    QHash<QString, int> appsPerCategory;
    for (const auto &g : groups) {
        const auto map = g.toMap();
        appsPerCategory[map.value(QStringLiteral("category")).toString()]
            = map.value(QStringLiteral("apps")).toList().size();
    }
    QCOMPARE(appsPerCategory.value(QStringLiteral("Dev")), 2);
    QCOMPARE(appsPerCategory.value(QStringLiteral("Util")), 1);
}

void TestAppFilterModel::countSignalEmitsOnSourceChange()
{
    QSignalSpy spy(&m_filter, &AppFilterModel::countChanged);
    m_source.setApps({
        {QStringLiteral("A"), {}, {}, {}, {}, QStringLiteral("a"), {}, {}, {}},
    });
    QVERIFY(spy.count() >= 1);
    QCOMPARE(m_filter.count(), 1);
}

QTEST_MAIN(TestAppFilterModel)
#include "test_appfiltermodel.moc"
