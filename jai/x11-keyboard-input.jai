// Adapted from <https://stackoverflow.com/questions/74932957/x11-sending-wrong-key-presses>
main :: () {
    display := XOpenDisplay(null);
    if (!display) {
        print("No display.\n");
        exit(1);
    }

    root := DefaultRootWindow(display);

    attrs: XSetWindowAttributes;
    attrs.event_mask = KeyPressMask;
    // attrs.event_mask = ExposureMask | PointerMotionMask | KeyPressMask | KeyReleaseMask;

    window := XCreateWindow(display, root,
                           100, 100, 320, 240,
                           0, CopyFromParent, InputOutput, xx CopyFromParent,
                           CWEventMask, *attrs);
    XStoreName(display, window, "Example Program");

    close_window := XInternAtom(display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(display, window, *close_window, 1);

    XMapWindow(display, window);
    XFlush(display);

    while true {
        event: XEvent;
        XNextEvent(display, *event);
        if (event.type == ClientMessage && cast(Atom)(event.xclient.data.l[0]) == close_window)
            break;

        if event.type == {

        case MotionNotify;
            // It's just mouse motion events, so we won't mention those.

        case KeyPress;
            print("KeyPress event: state = %u (", event.xkey.state);
            if (event.xkey.state & ShiftMask) print(" Shift");
            if (event.xkey.state & LockMask) print(" CapsLock");
            if (event.xkey.state & ControlMask) print(" Control");
            if (event.xkey.state & Mod1Mask) print(" Mod1");
            if (event.xkey.state & Mod2Mask) print(" Mod2");
            if (event.xkey.state & Mod3Mask) print(" Mod3");
            if (event.xkey.state & Mod4Mask) print(" Mod4");
            if (event.xkey.state & Mod5Mask) print(" Mod5");
            print(" ), keycode = %u\n", event.xkey.keycode);

        case KeyRelease;
            print("KeyRelease event: state = %u (", event.xkey.state);
            if (event.xkey.state & ShiftMask) print(" Shift");
            if (event.xkey.state & LockMask) print(" CapsLock");
            if (event.xkey.state & ControlMask) print(" Control");
            if (event.xkey.state & Mod1Mask) print(" Mod1");
            if (event.xkey.state & Mod2Mask) print(" Mod2");
            if (event.xkey.state & Mod3Mask) print(" Mod3");
            if (event.xkey.state & Mod4Mask) print(" Mod4");
            if (event.xkey.state & Mod5Mask) print(" Mod5");
            print(" ), keycode = %u\n", event.xkey.keycode);

        case Expose;
            print("Expose event: x=%d, y=%d, width=%d, height=%d, count=%d\n", event.xexpose.x, event.xexpose.y, event.xexpose.width, event.xexpose.height, event.xexpose.count);

        case;
            print("Event type %d\n", event.type);
        }
    }

    XCloseDisplay(display);
    exit(0);
}

#import "X11";
#import "Basic";
