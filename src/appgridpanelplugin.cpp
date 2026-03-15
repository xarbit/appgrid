/*
    SPDX-FileCopyrightText: 2026 AppGrid Contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "appgridpanelplugin.h"

AppGridPanelPlugin::AppGridPanelPlugin(QObject *parent, const KPluginMetaData &data, const QVariantList &args)
    : AppGridPlugin(parent, data, args)
{
    m_useNativeActivation = true;
}

K_PLUGIN_CLASS_WITH_JSON(AppGridPanelPlugin, "metadata-panel.json")

#include "appgridpanelplugin.moc"
