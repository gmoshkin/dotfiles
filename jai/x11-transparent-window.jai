// Adapted from <https://stackoverflow.com/a/13397150>
main :: () {
    display := XOpenDisplay(null);

    vinfo: XVisualInfo;

    XMatchVisualInfo(display, DefaultScreen(display), 32, TrueColor, *vinfo);

    transparent_background_pixel := 0x10101010;
    opaque_background_pixel := 0xff101010;
    is_transparent := false;

    attr: XSetWindowAttributes;
    attr.colormap = XCreateColormap(display, DefaultRootWindow(display), vinfo.visual, AllocNone);
    attr.border_pixel = 0;
    attr.background_pixel = xx ifx is_transparent then transparent_background_pixel else opaque_background_pixel;
    attr.event_mask = KeyPressMask;

    win := XCreateWindow(display, DefaultRootWindow(display), 0, 0, 300, 200, 0, vinfo.depth, InputOutput, vinfo.visual, xx (CWColormap | CWBorderPixel | CWBackPixel | CWEventMask), *attr);
    // XSelectInput(display, win, StructureNotifyMask);
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
            case KeyPress;
                is_transparent = !is_transparent;
                color := Vector4.{ .1, .1, .1, 1 };
                if is_transparent color /= 2;
                background_pixel := rgb_to_x11_pixel(color);
                print("background_pixel: %\n", FormatInt.{ value = background_pixel, base = 16, minimum_digits = 8 });
                rc := XSetWindowBackground(display, win, xx background_pixel);
                print("rc: %\n", rc);
                rc = XClearWindow(display, win);
                print("rc: %\n", rc);
        }
    }

    XDestroyWindow(display, win);
    XCloseDisplay(display);
}

rgb_to_x11_pixel :: (rgb: Vector4) -> u32 {
    to_byte :: inline (c: float) -> u32 {
        return xx (c * 0xff);
    }
    res: u32 = (to_byte(rgb.w) << 24) | (to_byte(rgb.z) << 16) | (to_byte(rgb.y) << 8) | to_byte(rgb.x);
    return res;
}

TrueColor :: 4;

#import "Math";
#import "X11";
#import "Basic";
