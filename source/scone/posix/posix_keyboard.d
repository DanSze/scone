module scone.posix.posix_keyboard;

version(Posix):
package(scone):

    import core.stdc.stdio;
    import core.sys.posix.termios;

import scone.keyboard;
import scone.utility : hasFlag;
import scone.core;

extern(C) void cfmakeraw(termios *termios_p);

auto posix_initKeyboard()
{
    //Open stdin in raw mode
    tcgetattr(1, &ostate); //save old state
    tcgetattr(1, &nstate); //get base of new state
    cfmakeraw(&nstate);
    tcsetattr(1, TCSADRAIN, &nstate);
}

auto posix_exitKeyboard()
{
    tcsetattr(1, TCSADRAIN, &ostate);
}

@disable auto posix_getInput()
{
    //KeyEvent();
    int key = fgetc(stdin);
}

private:
termios ostate; //Saved tty state
termios nstate; //Values for editor mode
