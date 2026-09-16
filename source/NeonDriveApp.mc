using Toybox.Application;

class NeonDriveApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new NeonDriveView() ];
    }
}
