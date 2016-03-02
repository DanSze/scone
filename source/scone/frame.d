module scone.frame;

import scone.core;
import scone.window;
import std.algorithm : max, min;
import std.array : insertInPlace;
import std.conv : to, text;
import std.format : format;
import std.stdio;
import std.string : wrap, strip;
import std.traits : isArray, isSomeString;
import std.uni : isWhite;
import scone.utility;

/**
 * Universal enum to do certain operations.
 *
 * As it is less than 1, it is used to set dynamic width and height for windows.
 * Examples:
 * --------------------
 * auto window = new Frame(UNDEF, 20);
 * --------------------
 * Will probably be used sometime in the future
 */
enum UNDEF = -1;

/**
 * Slot structure
 *
 * Examples:
 * --------------------
 * Slot slot1 = Slot('d', fg.red, bg.white); //'d' character with RED foreground color and WHITE background color
 * Slot slot2 = Slot('g');
 *
 * auto window = new Frame();
 * window.write(0,0, slot1);
 * window.write(0,1, slot2);
 * --------------------
 *
 */
struct Slot
{
    char character;
    fg foreground = fg.init;
    bg background = bg.init;
}

/**
 * All colors
 * --------------------
 * //Available colors:
 * init
 *
 * black
 * blue
 * blue_dark
 * cyan
 * cyan_dark
 * gray
 * gray_dark
 * green
 * green_dark
 * magenta
 * magenta_dark
 * red
 * red_dark
 * white
 * yellow
 * yellow_dark
 * --------------------
 * Examples:
 * ---
 * window.write(fg.white, bg.red, "scone"); //Writes "scone" in white with red background
 * ---
 */
alias fg = colorTemplate!(colorType.foreground).color;
///ditto
alias bg = colorTemplate!(colorType.background).color;


/**
 * Writable area
 */
class Frame
{
    alias width = w;
    alias height = h;

    //@nogc: //In the future, make entire Frame @nogc

    /**
     * Main frame constructor.
     * Params:
     *   width  = Width of the main frame. If less than 1, get set to the consoles width (in slots)
     *   height = Height of the main frame. If less than 1, get set to the consoles height (in slots)
     *
     * Examples:
     * --------------------
     * //Creates a dynamically sized main frame, where the size is determined by the console/terminal window width and height
     * auto window = new Frame(); //The main frame
     *
     * //The width is less than one, meaning it get dynamically set to the consoles
     * auto window = new Frame(0, 20); //Main frame, with the width of the console/terminal width, and the height of 20
     *
     * //The width is less than one, meaning it get dynamically set to the consoles
     * auto window = new Frame(UNDEF, 24); //Main frame, with the width of the console/terminal width, the height of 24
     * --------------------
     *
     * Standards: width = 80, height = 24
     *
     * If the width or height exceeds the consoles width or height, the program errors.
     */
    this(int width = UNDEF, int height = UNDEF)
    in
    {
        auto size = windowSize;
        sconeCrashIf(width > size[0] || height > size[1], "Frame is too small. Minimum size needs to be %sx%s slots, but frame size is %sx%s", width, height, size[0], size[1]);
    }
    body
    {
        auto size = windowSize;
        if(width  < 1){ width  = size[0]; }
        if(height < 1){ height = size[1]; }

        _w = width;
        _h = height;

        _slots = new Slot[][](height, width);
        _backbuffer = new Slot[][](height, width);

        foreach(n, ref row; _slots)
        {
            row = _slots[n][] = Slot(' ');
        }
    }

    /**
     * Writes whatever is thrown into the parameters onto the frame
     * Examples:
     * --------------------
     * window.write(10,15, fg.red, bg.green, 'D'); //Writes a 'D' colored RED with a GREEN background.
     * window.write(10,16, fg.red, bg.white, "scon", fg.blue, 'e'); //Writes "scone" where "scon" is YELLOW with WHITE background and "e" is RED with WHITE background.
     * window.write(10,17, bg.red, fg.blue);
     * window.write(10,17, bg.white, fg.green); //Changes the slots' color to RED and the background to WHITE.
     *
     * window.write(10,18, 'D', bg.red); //Watch out: This will print "D" with the default color and the default background-color.
     * --------------------
     * Note: Using Unicode character may not work as expected, due to different operating systems may not handle Unicode correctly.
     */
    auto write(Args...)(in int col, in int row, Args args)
    {
        //Check if writing outside border
        if(col < 0 || row < 0 || col > w || row > h)
        {
            log.logf("Warning: Cannot write at (%s, %s). x must be between 0 <-> %s, y must be between 0 <-> %s", col, row, w, h);
            return;
        }

        Slot[] slots;
        fg foreground = fg.white;
        bg background = bg.black;

        bool unsetColors;
        foreach(arg; args)
        {
            static if(is(typeof(arg) == fg))
            {
                foreground = arg;
                unsetColors = true;
            }
            else static if(is(typeof(arg) == bg))
            {
                background = arg;
                unsetColors = true;
            }
            else static if(is(typeof(arg) == Slot))
            {
                slots ~= arg;
                unsetColors = false;
            }
            else
            {
                foreach(c; to!string(arg))
                {
                    slots ~= Slot(c, foreground, background);
                }
                unsetColors = false;
            }
        }

        //If the last argument is a color, warn
        if(slots.length && unsetColors)
        {
            log.logf("Warning: The last argument in %s is a color, which will not be set!", args);
        }

        if(!slots.length)
        {
            _slots[row][col].foreground = foreground;
            _slots[row][col].background = background;
        }
        else
        {
            int wx, wy;
            foreach(slot; slots)
            {
                if(col + wx >= w || slot.character == '\n')
                {
                    wx = 0;
                    ++wy;
                    continue;
                }
                else
                {
                    _slots[row + wy][col + wx] = slot;
                    ++wx;
                }
            }
        }
    }

    /** Prints the frame to the console */
    auto print()
    in
    {
        //Makes sure the frame isn't resized to a smaller size than the window.
        //TODO: Make a test to see how performance heavy this is (probably not that much)
        auto a = windowSize();
        sconeCrashIf(a[0] < w || a[1] < h, "The window is smaller than the frame");
    }
    body
    {
        version(Windows)
        {
            foreach(sy, ref row; _slots)
            {
                foreach(sx, ref slot; row)
                {
                    if(slot != _backbuffer[sy][sx])
                    {
                        writeSlot(sx,sy, slot);
                        _backbuffer[sy][sx] = slot;
                    }
                }
            }
        }
        else version(Posix)
        {
            //Temporary string that will be printed out for each line.
            string printed;

            //Loop through all rows.
            foreach (sy, row; _slots)
            {
                //f = first modified slot, l = last modified slot
                int f = UNDEF, l;

                //Go through each line
                foreach(sx, slot; _slots[sy])
                {
                    //If the slot at current position differs from backbuffer
                    if(slot != _backbuffer[sy][sx])
                    {
                        //Set f once
                        if(f == UNDEF)
                        {
                            f = to!int(sx);
                        }

                        //Update l as many times as needed
                        l = to!int(sx);

                        //Backbuffer is checked, make it "un-differ"
                        _backbuffer[sy][sx] = slot;
                    }
                }

                //If no slot on this row has been modified, continue
                if(f == UNDEF)
                {
                    continue;
                }

                //Loop from the first changed slot to the last edited slot.
                foreach (px; f .. l + 1)
                {
                    printed ~= text("\033[", 0, ";", cast(int)_slots[sy][px].foreground, ";", cast(int)_slots[sy][px].background, "m", _slots[sy][px].character, "\033[0m");
                }

                //Set the cursor at the firstly edited slot...
                setCursor(f, to!int(sy));
                //...and then print out the string.
                std.stdio.write(printed);

                //Reset 'printed'.
                printed = null;
            }
            //Flush. Without this problems may occur.
            stdout.flush(); //TODO: Check if needed for POSIX. I know without this it caused a lot of problems on the Windows console, but you know... this part is POSIX only
        }
    }

    ///Sets all tiles to blank
    auto clear()
    {
        foreach(ref row; _slots)
        {
            row[] = Slot(' ');
        }
    }

    ///Causes next `print()` to write out all tiles.
    auto flush()
    {
        foreach(ref row; _backbuffer)
        {
            row[] = Slot(' ');
        }
    }

    const
    {
        /** Get the width of the frame */
        auto w() @property
        {
            return _w;
        }

        /** Get the height of the frame */
        auto h() @property
        {
            return _h;
        }

        /** Returns: Slot at the specific x and y coordinates */
        auto getSlot(in int x, in int y)
        {
            return _slots[y][x];
        }
    }

    private:
    //Forgive me for using C++ naming style
    int _w, _h;
    Slot[][] _slots, _backbuffer;
}

//Do not delete:
//hello there kott and blubeeries, wat are yoy doing this beautyiur beuirituyr nightrevening?? i am stiitngi ghere hanad dtyryugin to progrmamam this game enrgniergn that is for the solnosle
