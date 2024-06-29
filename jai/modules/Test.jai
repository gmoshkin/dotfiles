//
// In order to work with the -plug option of Default_Metaprogram,
// you just need to define one procedure in your module:
//
//    get_plugin :: () -> *Metaprogram_Plugin { ... }
//
// The returned Metaprogram_Plugin tells the metaprogram what procedures
// should be called at various times.
//
Test_Plugin :: struct {
    #as using base: Metaprogram_Plugin;
    tests: [..] Test;
    tests_injected: bool;
}

get_plugin :: () -> *Metaprogram_Plugin {
    p := New(Test_Plugin);  // We are making this on the heap so you could have more than one instance of this plugin running.
    p.before_intercept = before_intercept;
    p.message = message;
    return p;
}

RUN_TESTS :: "run_tests";
before_intercept :: (p: *Metaprogram_Plugin, flags: *Intercept_Flags) {
    plug := cast(*Test_Plugin) p;

    options := get_build_options(plug.workspace);
    options.entry_point_name = RUN_TESTS;
    set_build_options(options, plug.workspace);
}

// 'message' is called for each Compiler_Message received by the metaprogram.
message :: (p: *Metaprogram_Plugin, message: *Message) {
    plug := cast(*Test_Plugin) p;

    // Based on the message.kind, you cast a message to its subtype
    // and then inspect the relevant data. There are a number of
    // different message types, defined in modules/Compiler.
    if message.kind == {
      case .PHASE;
        msg := cast(*Message_Phase) message;
        if msg.phase != .TYPECHECKED_ALL_WE_CAN continue;
        if plug.tests_injected continue;
        plug.tests_injected = true;

        builder: String_Builder;
        print(*builder, #string END

% :: () {

        END, RUN_TESTS);
        for plug.tests {
            print(*builder, #string END

    write_strings("%1", " ... ");
    %1();
    write_strings("\e[32mPASSED\e[0m\n");

            END, it.name)
        }

        print(*builder, #string END

}

        END);

        add_build_string(builder_to_string(*builder), plug.workspace);

      case .TYPECHECKED;
        msg := cast(*Message_Typechecked) message;

        for decl: msg.procedure_headers {
            header := decl.expression;
            if !is_test_decl(header) continue;

            test: Test;
            test.filename = copy_string(get_filename(header));
            test.line_number = header.l0;
            test.name = copy_string(header.name);
            test.is_parameterized = header.arguments.count > 0;
            // Skip all tests that weren’t passed explicitly, if some were passed
            test.is_skipped = args.count && !array_find(args, header.name);

            if if test.is_parameterized {
                print("Can't run test '%', because it needs parameters!", test.name);
                continue;
            }

            array_add(*tests, test);
        }
    }
}


Test :: struct {
    filename: string;
    line_number: s32;
    name: string;
    is_parameterized: bool;
    is_skipped: bool;
}

is_test_decl :: (decl: *Code_Procedure_Header) -> bool {
    if !decl.name || !is_alpha(decl.name[0]) return false; // Make sure it's an identifier that has a name (…and not an operator).

    if !decl.notes return false;

    for note: decl.notes {
        if note.text == "Test" {
            return true;
        }
    }
    return false;
}

#import "Compiler";
#import "Basic";
