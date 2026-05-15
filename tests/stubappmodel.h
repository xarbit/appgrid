/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later

    Stub source model used by tests. Exposes the same role enum as AppModel
    but lets tests load arbitrary rows without touching KService/KSycoca.
*/

#pragma once

#include <QAbstractListModel>
#include <QVector>

#include "appmodel.h"

struct StubApp {
    QString name;
    QString icon;
    QString desktopFile;
    QStringList categories;
    QString genericName;
    QString storageId;
    QStringList keywords;
    QString comment;
    QString installSource;
};

class StubAppModel : public QAbstractListModel {
    Q_OBJECT
public:
    explicit StubAppModel(QObject *parent = nullptr) : QAbstractListModel(parent) {}

    void setApps(const QVector<StubApp> &apps)
    {
        beginResetModel();
        m_apps = apps;
        endResetModel();
    }

    int rowCount(const QModelIndex &parent = QModelIndex()) const override
    {
        return parent.isValid() ? 0 : m_apps.size();
    }

    QVariant data(const QModelIndex &index, int role) const override
    {
        if (!index.isValid() || index.row() < 0 || index.row() >= m_apps.size())
            return {};
        const auto &app = m_apps[index.row()];
        switch (role) {
        case AppModel::NameRole: return app.name;
        case AppModel::IconRole: return app.icon;
        case AppModel::DesktopFileRole: return app.desktopFile;
        case AppModel::CategoryRole: return app.categories.value(0);
        case AppModel::CategoriesRole: return app.categories;
        case AppModel::GenericNameRole: return app.genericName;
        case AppModel::StorageIdRole: return app.storageId;
        case AppModel::KeywordsRole: return app.keywords;
        case AppModel::CommentRole: return app.comment;
        case AppModel::InstallSourceRole: return app.installSource;
        }
        return {};
    }

private:
    QVector<StubApp> m_apps;
};
