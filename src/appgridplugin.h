#pragma once

#include <Plasma/Applet>

#include "appmodel.h"

class AppGridPlugin : public Plasma::Applet {
    Q_OBJECT
    Q_PROPERTY(AppFilterModel *appsModel READ appsModel CONSTANT)

public:
    AppGridPlugin(QObject *parent, const KPluginMetaData &data, const QVariantList &args);

    AppFilterModel *appsModel();

private:
    AppModel m_appModel;
    AppFilterModel m_filterModel;
};
