/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Verifies search relevance ordering: prefix > substring > generic > keyword.
*/

#include <QTest>

#include "appfiltermodel.h"
#include "stubappmodel.h"

class TestSearchRanking : public QObject {
    Q_OBJECT
private slots:
    void initTestCase();
    void init();
    void prefixBeatsSubstring();
    void substringBeatsGeneric();
    void genericBeatsKeyword();
    void launchCountTiebreaksWithinTier();
    void emptySearchUsesAlphabetical();

private:
    QString nameAt(int proxyRow) const;
    StubAppModel m_source;
    AppFilterModel m_filter;
};

void TestSearchRanking::initTestCase()
{
    m_filter.setSourceModel(&m_source);
}

void TestSearchRanking::init()
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
}

QString TestSearchRanking::nameAt(int row) const
{
    return m_filter.index(row, 0).data(AppModel::NameRole).toString();
}

void TestSearchRanking::prefixBeatsSubstring()
{
    m_source.setApps({
        {QStringLiteral("Blender"), {}, {}, {}, {}, QStringLiteral("a"), {}, {}, {}},
        {QStringLiteral("Tableau"), {}, {}, {}, {}, QStringLiteral("b"), {}, {}, {}}, // contains "able"
        {QStringLiteral("Able-Editor"), {}, {}, {}, {}, QStringLiteral("c"), {}, {}, {}}, // prefix "Able"
    });
    m_filter.setSearchText(QStringLiteral("able"));
    QCOMPARE(m_filter.count(), 2);
    QCOMPARE(nameAt(0), QStringLiteral("Able-Editor")); // prefix wins
    QCOMPARE(nameAt(1), QStringLiteral("Tableau"));
}

void TestSearchRanking::substringBeatsGeneric()
{
    m_source.setApps({
        {QStringLiteral("Firefox"), {}, {}, {}, QStringLiteral("Web Browser"), QStringLiteral("a"), {}, {}, {}},
        {QStringLiteral("Konqueror"), {}, {}, {}, QStringLiteral("Web Browser"), QStringLiteral("b"), {}, {}, {}},
        {QStringLiteral("ProBrowse"), {}, {}, {}, QStringLiteral("File Manager"), QStringLiteral("c"), {}, {}, {}}, // name substring
    });
    m_filter.setSearchText(QStringLiteral("brow"));
    QCOMPARE(m_filter.count(), 3);
    QCOMPARE(nameAt(0), QStringLiteral("ProBrowse")); // substring beats generic
}

void TestSearchRanking::genericBeatsKeyword()
{
    m_source.setApps({
        {QStringLiteral("Foo"), {}, {}, {}, QStringLiteral("Photo Editor"), QStringLiteral("a"), {}, {}, {}},
        {QStringLiteral("Bar"), {}, {}, {}, {}, QStringLiteral("b"), {QStringLiteral("photo")}, {}, {}},
    });
    m_filter.setSearchText(QStringLiteral("photo"));
    QCOMPARE(m_filter.count(), 2);
    QCOMPARE(nameAt(0), QStringLiteral("Foo")); // generic beats keyword
}

void TestSearchRanking::launchCountTiebreaksWithinTier()
{
    m_source.setApps({
        {QStringLiteral("Editor A"), {}, {}, {}, {}, QStringLiteral("a"), {}, {}, {}},
        {QStringLiteral("Editor B"), {}, {}, {}, {}, QStringLiteral("b"), {}, {}, {}},
        {QStringLiteral("Editor C"), {}, {}, {}, {}, QStringLiteral("c"), {}, {}, {}},
    });
    QVariantMap counts;
    counts[QStringLiteral("b")] = 50;
    counts[QStringLiteral("a")] = 10;
    counts[QStringLiteral("c")] = 0;
    m_filter.setLaunchCountsMap(counts);
    m_filter.setSearchText(QStringLiteral("editor"));
    QCOMPARE(m_filter.count(), 3);
    QCOMPARE(nameAt(0), QStringLiteral("Editor B")); // highest launch count first
    QCOMPARE(nameAt(1), QStringLiteral("Editor A"));
    QCOMPARE(nameAt(2), QStringLiteral("Editor C"));
    m_filter.setSearchText(QString());
    m_filter.setLaunchCountsMap({});
}

void TestSearchRanking::emptySearchUsesAlphabetical()
{
    m_source.setApps({
        {QStringLiteral("Zebra"), {}, {}, {}, {}, QStringLiteral("a"), {}, {}, {}},
        {QStringLiteral("Apple"), {}, {}, {}, {}, QStringLiteral("b"), {}, {}, {}},
        {QStringLiteral("Mango"), {}, {}, {}, {}, QStringLiteral("c"), {}, {}, {}},
    });
    m_filter.setSearchText(QString());
    QCOMPARE(m_filter.count(), 3);
    QCOMPARE(nameAt(0), QStringLiteral("Apple"));
    QCOMPARE(nameAt(1), QStringLiteral("Mango"));
    QCOMPARE(nameAt(2), QStringLiteral("Zebra"));
}

QTEST_MAIN(TestSearchRanking)
#include "test_search_ranking.moc"
