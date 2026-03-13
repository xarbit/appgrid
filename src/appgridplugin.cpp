#include "appgridplugin.h"

K_PLUGIN_CLASS_WITH_JSON(AppGridPlugin, "metadata.json")

AppGridPlugin::AppGridPlugin(QObject *parent, const KPluginMetaData &data, const QVariantList &args)
    : Plasma::Applet(parent, data, args)
{
    m_filterModel.setSourceModel(&m_appModel);
}

AppFilterModel *AppGridPlugin::appsModel()
{
    return &m_filterModel;
}

#include "appgridplugin.moc"
