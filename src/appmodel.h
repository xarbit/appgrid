#pragma once

#include <QAbstractListModel>
#include <QSortFilterProxyModel>
#include <QString>
#include <QVariantMap>
#include <QVector>

struct AppEntry {
    QString name;
    QString icon;
    QString desktopFile;
    QString category;
    QString genericName;
    QString exec;
};

class AppModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        IconRole,
        DesktopFileRole,
        CategoryRole,
        GenericNameRole,
    };

    explicit AppModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void launch(int index);
    Q_INVOKABLE QStringList categories() const;

private:
    void loadApplications();
    QString mapCategory(const QStringList &categories) const;

    QVector<AppEntry> m_apps;
    QStringList m_categories;
};

class AppFilterModel : public QSortFilterProxyModel {
    Q_OBJECT
    Q_PROPERTY(QString filterCategory READ filterCategory WRITE setFilterCategory NOTIFY filterCategoryChanged)
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit AppFilterModel(QObject *parent = nullptr);

    QString filterCategory() const;
    void setFilterCategory(const QString &category);

    QString searchText() const;
    void setSearchText(const QString &text);

    int count() const;

    Q_INVOKABLE void launch(int proxyIndex);
    Q_INVOKABLE QStringList categories() const;
    Q_INVOKABLE QVariantMap get(int proxyRow) const;

signals:
    void filterCategoryChanged();
    void searchTextChanged();
    void countChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;
    bool lessThan(const QModelIndex &left, const QModelIndex &right) const override;

private:
    QString m_filterCategory;
    QString m_searchText;
};
