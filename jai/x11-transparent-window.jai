main :: () {
    display := XOpenDisplay(null);

    vinfo: XVisualInfo;

    XMatchVisualInfo(display, DefaultScreen(display), 32, TrueColor, *vinfo);

    attr: XSetWindowAttributes;
    attr.colormap = XCreateColormap(display, DefaultRootWindow(display), vinfo.visual, AllocNone);
    attr.border_pixel = 0;
    attr.background_pixel = 0x10101010;

    win := XCreateWindow(display, DefaultRootWindow(display), 0, 0, 300, 200, 0, vinfo.depth, InputOutput, vinfo.visual, xx (CWColormap | CWBorderPixel | CWBackPixel), *attr);
    XSelectInput(display, win, StructureNotifyMask);
    gc := XCreateGC(display, win, 0, null);

    wm_delete_window := XInternAtom(display, "WM_DELETE_WINDOW", 0);
    XSetWMProtocols(display, win, *wm_delete_window, 1);

    XMapWindow(display, win);

    keep_running := true;
    event: XEvent;

    while keep_running {
        XNextEvent(display, *event);

        if event.type == {
            case ClientMessage;
                if event.xclient.message_type == XInternAtom(display, "WM_PROTOCOLS", 1) && cast(Atom)event.xclient.data.l[0] == XInternAtom(display, "WM_DELETE_WINDOW", 1) {
                    print("end\n");
                    keep_running = false;
                }
        }
    }

    XDestroyWindow(display, win);
    XCloseDisplay(display);
}

TrueColor :: 4;

#import "X11";
#import "Basic";
