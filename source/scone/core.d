module scone.core;

import scone.utility;
import scone.frame;
import scone.window;
import scone.keyboard;
import scone.locale;
import std.experimental.logger;

/**
 * Initializes scone.
 * Must be run only once in order to use scone's features.
 */
auto sconeOpen()
{
    openWindow();
    openKeyboard();
    //openAudio();

    setLocale("en_US");
}

/**
 * Closes scone.
 * Recommended to be run at end of program.
 */
auto sconeClose()
{
    closeWindow();
    closeKeyboard();
    //closeAudio();
}

static FileLogger sconeLog;
