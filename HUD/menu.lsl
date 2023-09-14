// ===========================================================================
// Act! Menu                                                                 \
// By Jack Abraham                                                        \__
// ===========================================================================

// Check this stuff for each installation
string helpURL =                        // URL for web page
    "http://mysticgems.wordpress.com/";
vector DIM_COLOR = <0.5, 0.5, 0.5>;
vector LIT_COLOR = <1.0, 0.5, 0.5>;
list lightupButtons =                   // Buttons to light/dim when clicked
    [ "act!:amenu", "act!:team:menu", "trvl:follow", 
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
float MENU_TIME             = 10.0;     // Time before a menu expires

integer BROADCAST_MASK      = 0xFFF00000;
integer RP_MASK             = 0x4000000;

string CHAT_DELIM = "|";
string LINK_DELIM = "§";
string ACT_DELIM = ":";

// -------------------------------------------------------------------------
// Menuing

option_menu()
{
    title = "Options";
    buttons = [ "Help", "Diags", "RESET", "Flight", "Plugins" ];
    commands = [ "help", "diag", "rset", "trvl§menu", "plug§menu" ];
    replyTo = LINK_SET;
    replyMask = BROADCAST_MASK;
    display_menu();
}

display_menu()
{
    start_menu_listen();
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

set_target( key id )
{
    llLinksetDataWrite( "target", id );
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
                targeting = TRUE;
                llSensor( "", NULL_KEY, AGENT, 96.0, PI_BY_TWO );
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
        
        // llOwnerSay( llGetScriptName() + " " + message );

        if ( cmd == "menu" ) {
            title = llList2String( msg, 1 );
            buttons = llCSV2List( llList2String( msg, 2 ) );
            commands = llCSV2List( 
                llDumpList2String( llList2List( msg, 3, -1 ), LINK_DELIM ) );
            replyTo = source;
            replyMask = flag;
            display_menu();
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
        }
    }
    
    control( key id, integer held, integer change )
    {
        if ( change & CONTROL_LBUTTON ) {
            if ( held ) {
                llResetTime();
            } else if ( llGetAndResetTime() > 0.25 ) {
                targeting = TRUE;
                llSensor( "", NULL_KEY, AGENT, 
                    96.0, PI_BY_TWO );
            }
        }
        if ( ( ~held & change & CONTROL_ML_LBUTTON ) )
        {
            targeting = TRUE;
            llSensor( "", NULL_KEY, AGENT, 
                96.0, PI_BY_TWO );
        }
    }

    sensor( integer n )
    {
        // Adjust position for eye level
        vector mypos = llGetCameraPos();
        // Current forward vector
        vector fwd = llRot2Fwd(llGetCameraRot());
        integer f = 0;
        key id;
        vector pos;
        list boxList;
        vector box;
        vector nearest;
        float zDiff;
        float xyDiff;
        key target = NULL_KEY; // key of identified target
        targeting = FALSE;
        do {
            id = llDetectedKey(f);
            // This returns a list; we assume the avatar has
            // a bounding box that is symmetrical about their axes
            // and calculate its size based on the maximum corner.
            // Diameter of the "cylinder" is based on width.
            boxList = llGetBoundingBox(id);
            pos = llDetectedPos(f);
            box = llList2Vector(boxList, 1);
            // Nearest point along the forward axis to the target's
            // position
            nearest = fwd * (fwd * (pos - mypos)) + mypos;
            // Find the distances of this from target pos on the XY plane
            // and the Z axis
            zDiff = llVecMag(<0.0, 0.0, nearest.z> - <0.0, 0.0, pos.z>);
            xyDiff = llVecMag(<nearest.x, nearest.y, 0.0> 
                - <pos.x, pos.y, 0.0>);
            if (xyDiff <= (box.y + box.x) / 2 && zDiff <= box.z) {
                // projection of forward vector within box
                target = id;
                set_target( id );
                llPlaySound( "46e2dd13-85b4-8c91-ab62-7d5c4dd16068", 0.5 );
            }
        } while (++f < n && target == NULL_KEY);
        if ( target == NULL_KEY ) {
            llSensor( "", NULL_KEY, ACTIVE | PASSIVE, 96.0, PI_BY_TWO );
        }
    }
    
    no_sensor()
    {
        if ( targeting ) {
            targeting = FALSE;
            llSensor( "", NULL_KEY, ACTIVE | PASSIVE, 96.0, PI_BY_TWO );
        }
    }
}

