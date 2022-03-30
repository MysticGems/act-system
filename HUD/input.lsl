// ===========================================================================
// Act! Menu                                                                 \
// By Jack Abraham                                                        \__
// ===========================================================================

// Check this stuff for each installation
string helpURL =                        // URL for web page
    "http://github.com/MysticGems/act-system/wiki";
vector DIM_COLOR = <0.5, 0.5, 0.5>;
vector LIT_COLOR = <1.0, 0.5, 0.5>;
list lightupButtons =                   // Buttons to light/dim when clicked
    [ "act!:team:menu", "trvl:follow", 
    "act!:focus", "help", "options", "ping" ];

// Should be safe below here =================================================

integer DIM_FACE = 2;
integer LIT_FACE = 0;

// Menu syntax
// Integer field
//      integer to reply with
// String field
//      menu:<string menu title>:<csv button labels>:<csv return commands>

string title;                           // Menu label
list buttons;                           // Buttons shown on the menu
list commands;                          // What the buttons mean
integer replyTo;                        // Prim requesting the menu
integer replyMask;                      // Mask for reply
key target;

integer menuChannel;                    // Menu listener channel
integer menuHandle;                     // Menu listener handle
integer menuIdx;                        // Which menu item are we on
integer targeting;                      // Targeting in progress

integer held;                           // Is the button being held down?
integer ticks;                          // How long was the button held?
integer MAX_TICKS = 20;                 // Max ticks a button can be held

integer MAX_MENU_ITEMS      = 10;
string NEXT                 = ">>";
string PREV                 = "<<";
string CANCEL               = "[ CANCEL ]";
float MENU_TIME             = 10.0;     // Time before a menu expires

integer BROADCAST_MASK      = 0xFFF00000;
integer RP_MASK             = 0x4000000;
integer UI_MASK             = 0x80000000;

string CHAT_DELIM = "|";
string LINK_DELIM = "§";
string ACT_DELIM = ":";

// -------------------------------------------------------------------------
// Menuing

option_menu()
{
    title = "Options";
    buttons = [ "Powers", "Plugins", "Flight", "Help", "Diags", "RESET" ];
    commands = [ "powers", "plug§menu", "trvl§menu",  "help", "diag", "rset" ];
    replyTo = LINK_SET;
    replyMask = BROADCAST_MASK;
    display_menu();
}

powers_menu()
{
    string name_prefix = "slot";
    integer len = llStringLength( name_prefix ) - 1;
    integer f = llGetNumberOfPrims();
    integer pos = -1;
    title = "Powers Management\nPick a slot n to manage";
    replyMask = UI_MASK;
    do {
        if ( llGetSubString( llGetLinkName( f ), 0, len ) == name_prefix ) {
            buttons += [ llGetLinkName( f ) ];
            commands += [ "addpwr§" + (string)f ];
        }
    } while (--f > 0);
    
    display_menu();
}

display_menu()
{
    buttons += [ CANCEL ];
    commands += [ "cancel" ];
    // Sort the buttons like sane people. Thanks, Ugleh Ulrik.
    buttons = llList2List( buttons, -3, -1 ) + llList2List( buttons, -6, -4 ) +
        llList2List( buttons, -9, -7 ) + llList2List( buttons, -12, -10 );
    commands = llList2List( commands, -3, -1 ) + llList2List( commands, -6, -4 ) +
        llList2List( commands, -9, -7 ) + llList2List( commands, -12, -10 );
    start_menu_listen();
    // llOwnerSay( llGetScriptName() + ": " + llList2CSV( buttons ) );
    if ( llGetListLength( buttons ) > MAX_MENU_ITEMS ) {
        llDialog( llGetOwner(), title, [ PREV ]
            + llList2List( buttons, menuIdx, menuIdx + MAX_MENU_ITEMS - 3 )
            + [ NEXT ],
            menuChannel );
    } else {
        llDialog( llGetOwner(), title, buttons, menuChannel );
    }
}

start_menu_listen()
{
    llListenRemove( menuHandle );
    menuChannel = llGetUnixTime();
    menuHandle = llListen( menuChannel, "", llGetOwner(), "" );
    llSetTimerEvent( MENU_TIME );
}

end_menu()
{
    if ( menuHandle ) llSetTimerEvent( 0. );
    llListenRemove( menuHandle );
    menuHandle = FALSE;
    title = "";
    buttons = [];
    commands = [];
    menuIdx = 0;
    replyTo = LINK_SET;
    replyMask = BROADCAST_MASK;
}

integer busy()
{
    return llList2Integer( llGetLinkPrimitiveParams( LINK_ROOT, 
        [ PRIM_MATERIAL ] ), 0 );
}

set_busy( integer isBusy )
{
    llSetLinkPrimitiveParamsFast( LINK_ROOT, [ PRIM_MATERIAL, isBusy ] );
}

integer targetPrim;
float TARGET_RANGE = 20.0;

lockon()
{
    integer filter = 0; // RC_REJECT_LAND | RC_REJECT_PHYSICAL | RC_REJECT_NONPHYSICAL;
    // ed95715e-21e1-4096-85dc-20a6a9e8e2bc
    vector camera = llGetCameraPos();
    vector fwd = llRot2Fwd( llGetCameraRot() ) * TARGET_RANGE;
    list hits = llCastRay( camera, camera + fwd, 
        [
            RC_DATA_FLAGS, RC_GET_ROOT_KEY
            , RC_REJECT_TYPES, filter
        ] );
    if ( hits ) {
        target = llList2Key( hits, 0 );
        if ( llGetAgentSize( target ) != ZERO_VECTOR ) {
            set_target( target );
        } else {
            // target may be a seat
            llSensor( "", NULL_KEY, AGENT, TARGET_RANGE, PI );
        }
    }
}

set_target( key id )
{
    target = id;
    llSetLinkPrimitiveParamsFast( targetPrim,
        [ PRIM_DESC, (string)id ] );
    llMessageLinked( LINK_SET, BROADCAST_MASK, 
        llDumpList2String( [ "trgt", id ], LINK_DELIM ),
        llGetKey() );
}

key get_seat( key id ) {
    list details = llGetObjectDetails( id, [ OBJECT_ROOT ] );
    return llList2Key( details, 0 );
}

integer on_same_seat( key id, key my_root ) {
    list details = llGetObjectDetails( id, [ OBJECT_ROOT ] );
    if ( get_seat(id) == my_root ) {
        return TRUE;
    }
    return FALSE;
}

list get_link_numbers_for_names(list namesToLookFor)
{
    list linkNumbers = namesToLookFor;
    integer f = llGetNumberOfPrims();
    integer pos = -1;
    do {
        pos = llListFindList(namesToLookFor, [llGetLinkName(f)]);
        if (pos > -1) {
            linkNumbers = llListReplaceList(linkNumbers, [f], pos, pos);
        }
    } while (--f > 0);
    return linkNumbers;
}

// -------------------------------------------------------------------------
// External command handling

list EXTERNAL_COMMANDS = [];

integer userChannel;
integer userHandle;
integer key2channel( key id )
{
    return -1 * (integer)( "0x" + llGetSubString(id, -10, -3));
}

// ===========================================================================

default
{
    state_entry()
    {
        llSetColor( ZERO_VECTOR, ALL_SIDES );
        llSetColor( LIT_COLOR, LIT_FACE );
        llSetColor( DIM_COLOR, DIM_FACE );
        lightupButtons = get_link_numbers_for_names( lightupButtons );
        list prims = get_link_numbers_for_names( [ "target" ] );
        targetPrim = llList2Integer( prims, 0 );
        llSetLinkPrimitiveParamsFast( LINK_SET, [ PRIM_MATERIAL, FALSE ] );
        if ( llGetAttached() ) {
            llRequestPermissions( llGetOwner(), PERMISSION_TRACK_CAMERA |
                PERMISSION_TAKE_CONTROLS );
        }
        set_target( NULL_KEY );
        userChannel = key2channel( llGetOwner() );
        userHandle = llListen( userChannel, "", NULL_KEY, "" );
    }
    
    attach( key id )
    {
        if ( id ) {
            llRequestPermissions( id, PERMISSION_TRACK_CAMERA |
                PERMISSION_TAKE_CONTROLS );
        }
    }    
    
    run_time_permissions( integer perm )
    {
        if ( perm & PERMISSION_TAKE_CONTROLS ) {
            llTakeControls( CONTROL_ML_LBUTTON | CONTROL_LBUTTON, 
                TRUE, TRUE );
        }
    }
    
    changed( integer change )
    {
        if ( change & CHANGED_OWNER ) {
            llMessageLinked( LINK_SET, BROADCAST_MASK, "rset", llGetOwner() );
            llResetScript();
        }
    }
    
    touch_start( integer d )
    {
        if ( !busy() ) {
            llResetTime();
            ticks = 0;
            held = TRUE;
            integer prim = llDetectedLinkNumber( 0 );
            string name = llGetLinkName( prim );
            if ( name == "act!:focus" ) {
                llMessageLinked( LINK_SET, BROADCAST_MASK, 
                    llDumpList2String( llParseString2List( name, [":"], [] ), 
                        LINK_DELIM )
                    , llGetOwner() );
                llSetTimerEvent( 0.5 );
                ticks++;
            }
            llPlaySound( "aff7b933-8cb6-1584-9c06-edb0cc787912", 1.0 );
            if ( llListFindList( lightupButtons, [prim] ) > -1 ) {
                llSetLinkColor( prim, LIT_COLOR, ALL_SIDES );
            }
        } else {
            llPlaySound( "6703a883-3bcc-b8fe-e113-f9695e96d341", 1.0 );
        }
    }
    
    timer()
    {
        if ( held && ( ticks < MAX_TICKS ) ) {
            ticks++;
        } else if ( busy() ) {
            set_busy( FALSE );
        }
        end_menu();
    }
    
    touch_end( integer d )
    {
        integer prim = llDetectedLinkNumber( 0 );
        if ( !busy() ) {
            string button = llGetLinkName(prim );
            if ( button == "options" ) {
                option_menu();
            } else if ( button == "ping" ) {
                lockon();
            } else if ( button == "inventory" ) {
                llOwnerSay( "Inventory not yet implemented." );
            } else if ( button == "quest" ) {
                llOwnerSay( "Quest guide not yet implemented" );
            } else if ( button == "cmbt:attack" || button == "cmbt:defend" ) {
                llOwnerSay( "Sex Act! not yet implemented" );
            } else {
                if ( !ticks ) {
                    if ( llGetTime() >= 0.5 ) {
                        ticks = TRUE;
                    }
                }
                llMessageLinked( LINK_SET, BROADCAST_MASK | ticks, 
                    llDumpList2String( llParseString2List( button, [":"], [] ), 
                        LINK_DELIM )
                    , llGetOwner() );
                ticks = FALSE;
            }
        }
        if ( llListFindList( lightupButtons, [prim] ) > -1 ) {
            llSetLinkColor( prim, DIM_COLOR, ALL_SIDES );
        }
    }

    link_message( integer source, integer flag, string message, key id )
    {
        list msg = llParseString2List( message, [ LINK_DELIM ], []);
        string cmd = llList2String(msg, 0);
        
        // llOwnerSay( llGetScriptName() + " " + cmd );

        if ( cmd == "menu" ) {
            // llOwnerSay( llGetScriptName() + " " + message );
            title = llList2String( msg, 1 );
            buttons = llCSV2List( llList2String( msg, 2 ) );
            commands = llCSV2List( 
                llDumpList2String( llList2List( msg, 3, -1 ), LINK_DELIM ) );
            replyTo = source;
            replyMask = flag;
            // llOwnerSay( llGetScriptName() + " " + llList2CSV( buttons ) );
            display_menu();
        } else if ( cmd == "powers" ) {
            powers_menu();
        } else if ( cmd == "addpwr" ) {
            integer button = llList2Integer( msg, 1 );
            llMessageLinked( llList2Integer( msg, 1 ), UI_MASK, "hotbr", llGetOwner() );
        } else if ( cmd == "help" ) {
            llLoadURL( llGetOwner(), "Act! HUD manual", helpURL );
        } else if ( cmd == "rset" ) {
            llResetScript();
        } else if ( cmd == "diag" ) {
            llSay( 0, "MENU SYSTEM\n" + 
                (string)llGetFreeMemory() + " bytes free" );
        } else if ( cmd == "fmem" ) {
            llMessageLinked( source, llGetFreeMemory(), "fmem", id );
        }
    }

    listen( integer channel, string who, key id, string msg )
    {
        if ( channel == menuChannel ) {
            if ( msg == NEXT ) {
                menuIdx += MAX_MENU_ITEMS;
                if ( menuIdx < 0 ) {
                    menuIdx = llGetListLength( buttons ) - MAX_MENU_ITEMS;
                }
                display_menu();
            } else if ( msg == PREV ) {
                menuIdx -= MAX_MENU_ITEMS;
                if ( menuIdx > llGetListLength( buttons ) ) {
                    menuIdx = 0;
                }
                display_menu();
            } else if ( msg == CANCEL ) {
                end_menu();
            } else {
                integer i = llListFindList( buttons, [ msg ] );
                if ( i > -1 ) {
                    string command = llList2String( commands, i );
                 //   llOwnerSay( llGetScriptName() + " sending \"" + command +
                 //       "\" to " + llGetLinkName( replyTo ) + " with flag " +
                 //       (string)replyMask );
                    llMessageLinked( replyTo, replyMask,
                        command, id );
                }
                end_menu();
            }
        } else if ( channel == userChannel ) {
            integer internal = FALSE;
            
            // Security checks here.  Make sure this is either for me, from my
            // object, or from my override owner
            key from = llGetOwnerKey( id );
            internal = ( from == llGetOwner() );
            
            if ( llGetSubString( msg, 0, 35 ) == (string)llGetOwner() ) {
                msg = llGetSubString( msg, 37, -1 );
            } else if ( !internal ) {
                return;
            }
            
            // Pass on the command if it passes security
            list parsed = llParseStringKeepNulls( msg, [ CHAT_DELIM ], [] );
            string cmd = llToLower( llList2String( parsed, 0 ) );
            
            if ( internal || ( llListFindList( EXTERNAL_COMMANDS, [ cmd ] ) > -1 ) )
            {
                llMessageLinked( LINK_SET, BROADCAST_MASK,
                    llDumpList2String( parsed, LINK_DELIM ), id );
            }
        }
    }
    
    sensor( integer num ) {
        // See if avatars in range are sitting on the target
        list sitters;
        integer i;
        integer onSeat;
        integer found = FALSE;
        
        // TODO: Handle multiple other sitters
        while ( i < num ) {
            onSeat = on_same_seat( llDetectedKey(i), target );
            if ( onSeat == TRUE ) {
                target = llDetectedKey(i);
                set_target( target );
                found = TRUE;
            }
            i++;
        }
        if (!found) {
            target = NULL_KEY;
            set_target( target );
        }
    }
    
    no_sensor() {
        target = NULL_KEY;
        set_target( NULL_KEY );
    }
    
    control( key id, integer held, integer change )
    {
        if ( change & CONTROL_LBUTTON ) {
            if ( held ) {
                llResetTime();
            } else if ( llGetAndResetTime() > 0.25 ) {
                lockon();
            }
        }
        if ( ( ~held & change & CONTROL_ML_LBUTTON ) )
        {
            lockon();
        }
    }
}