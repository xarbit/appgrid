/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include "appgridplugin.h"

class AppGridPanelPlugin : public AppGridPlugin
{
    Q_OBJECT

public:
    AppGridPanelPlugin(QObject *parent, const KPluginMetaData &data, const QVariantList &args);
};
