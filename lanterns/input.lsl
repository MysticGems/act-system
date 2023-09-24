// =========================================================================
// User interface controller                                               \
// By Jack Abraham                                                      \__
// =========================================================================

integer debugging_on = FALSE;

// -------------------------------------------------------------------------

list currentModePrims;                  // Current prims expanded
integer currentMode = -1;               // Current mode
list optionPrims =                      // Prims for option menu
    [ "chat", "shade", "help", "rset", "diag", 
    "hand", "xcmd^pmnu", "opt^menu", "menu^toggle" ];
    // , "opt:dead1", "opt:dead2", "opt:dead3"
list actPrims =                         // Prims for Act! menu
    [ "act!^sex", "act!^life^menu", "act!^stuf^menu",
    "act!^team^menu", "act!^peace", 
    "act!^char","animate", "glow", "act!^stat" ];
list patrolPrims =                      // Patrol menu
    [ "sens^dead", "scan^filter", "scan^menu", "plug^menu",
    "sens^cam", "sens^point", 
    "trvl^tp", "trvl^anchor", "trvl^cruise", "trvl^follow", "trvl^tocam"
    ];
list constructPrims =                    // Constructs menu
    [ "objt^menu", "objt^camrez", "act!^focus", "chrg^level",
    "objt^all die", "objt^life", "plug^menu",
    "objt^amnu", "objt^die", "aura", "objt^cmnu" ];
list combatPrims =                      // Combat menu
    [ "objt^wpnopt", "aura", "cmbt^auto", "plug^menu",
    "trvl^follow", "cmbt^melee", "cmbt^defend", "cmbt^ranged",
    "objt^die", "objt^all die", "objt^amnu"
    ];

list modePrims =                        // Mode select prims
    [ "combat", "construct", "patrol", "Act!", "Ring Plugin" ];
list modes =                            // Mode select prims
    [ "combat", "construct", "patrol", "rp", "options" ];
list busyModes =
    [ 0, 1 ];
integer combatMode;                     // Act differently in combat
list sensorBarPrims =                   // Sensor sidebar controls
    [ "scan^mode^bio", "scan^mode^energy", "scan^mode^mass", 
    "scan^mode^scripts", "scan^mode^sim", 
    "trgt^00000000-0000-0000-0000-000000000000", "sens^probe",
    "scan^filter", "ping" ];
    
list touchStartPrims =                  // Prims that have power-up
    [ "objt^life", 0.25
    , "act!^focus", 0.5
    , "glow", 0.333 ];
float tick;                             // How long a tick should be
integer ticks;                          // How long held
integer MAX_TICKS = 20;                 // Most possible ticks
integer held = FALSE;                   // Touch being held

integer menuPrim;
integer shadePrim;

integer sethot = FALSE;                 // Setting hot button

integer shadeButtonPrim;
integer contrast = FALSE;

integer targeting = FALSE;              // Seeking a target

// -------------------------------------------------------------------------

vector NORMAL_COLOR = <1.0, 1.0, 1.0>;
vector HILIGHT = <0.5, 0.5, 0.5>;
integer LIT_FACE = 2;
integer DIM_FACE = 0;
key logo = "b802a410-d094-875a-041c-64c58750e4ec";
vector CENTER_SIZE = <0.05, 0.05, 0.5>;

parse_touch( integer link, integer held )
{
    string command = llDumpList2String( 
        llParseString2List( llGetLinkName( link ), LINK_DELIMS,
        [] ), LINK_MSG_DELIM );
    // llOwnerSay( llGetScriptName() + " parse_touch: " + command );
    // Check for hot button
    integer hot = llGetSubString( command, 0, 2 ) == "hot";
    // Always allow reset and ping
    if ( command == "rset" ) {
        llResetScript();
    } else if ( command == "ping" || link == 1 ) {
        target_ping();
    // Otherwise only if we hit an active button
    } else if ( llListFindList( currentModePrims, [ link ] ) > -1 ||
        llListFindList( sensorBarPrims, [ link ] ) > -1 || 
        llGetSubString( command, 0, 2 ) == "hot" || command == "turn" ||
        command == "quest" + LINK_MSG_DELIM + "menu" ) 
    {
        if ( hot ) {
            if ( sethot ) {
                if ( sethot < 0 ) {
                    sethot = link;
                    llSetLinkColor( link, HILIGHT, ALL_SIDES );
                    llOwnerSay( command + " selected." );
                } else if ( sethot == link ) {
                    sethot = FALSE;
                    llSetLinkColor( link, <1, 1, 1>, ALL_SIDES );
                }
                return;
            } else {
                list params =  llGetLinkPrimitiveParams( link, 
                    [PRIM_DESC, PRIM_COLOR, 0] );
                if ( llList2Vector( params, 1 ) != <1, 1, 1> ) {
                    return;
                } else {
                    command = llDumpList2String( 
                        llParseString2List( 
                            llList2String( params, 0 ),
                            LINK_DELIMS,
                            [] ), LINK_MSG_DELIM );
                }
            }
        }
        llMessageLinked( LINK_SET, get_link_channel( command ) | held, 
            command, llGetOwner() );
    } else if ( llListFindList( modePrims, [ link ] ) > -1 ) {
        set_mode( command, link );
    }
}

set_mode( string newMode, integer link )
{
    show_power_bar( llListFindList( showPowerModes, [ newMode ] ) > -1 );
    if ( link == currentMode ) {
        close_ring( currentModePrims );
        if ( currentMode > -1 ) {
            llSetLinkColor( currentMode, NORMAL_COLOR, 4 );
        }
        currentMode = -1;
        llMessageLinked( LINK_SET, BROADCAST_MASK,
            llDumpList2String( [ "mode", "" ], LINK_MSG_DELIM ),
            llGetOwner() );
        shade_open( FALSE );
    } else {
        if ( have_sfx() || newMode == "Act!" 
            || newMode == "Ring Plugin" ) 
        {
            if ( currentMode > -1 ) {
                llSetLinkColor( currentMode, NORMAL_COLOR, 4 );
            }
            llSetLinkColor( link, HILIGHT, 4 );
            if ( newMode == "combat" ) {
                // set_hot_open( TRUE );
                open_ring( combatPrims );
            } else if ( newMode == "Act!" ) {
                open_ring( actPrims );
            } else if ( newMode == "construct" ) {
                open_ring( constructPrims );
            } else if ( newMode == "Ring Plugin" ) {
                open_ring( optionPrims );
            } else if ( newMode == "patrol" ) {
                open_ring( patrolPrims );
            }
            shade_open( TRUE );
            currentMode = link;
            llMessageLinked( LINK_SET, BROADCAST_MASK,
                llDumpList2String( [ "mode", newMode ], LINK_MSG_DELIM ),
                llGetOwner() );
        } else {
            llMessageLinked( LINK_SET, COMMUNICATION_MASK,
                llDumpList2String( [ "IM", "No power source." ],
                    LINK_MSG_DELIM ),
                llGetOwner() );
        }
    }
}

integer get_link_channel( string command ) 
{
    string module = llGetSubString( command, 0, 3 );
    integer linkChannel;
    if ( command == "rlvr" || command == "plug" ) {
        return PLUG_MASK;
    } else if ( command == "scan" || command == "sens") {
        return SCAN_MASK;
    } else if ( command == "objt" || command == "chrg" ) {
        return CONSTRUCT_MASK;
    } else if ( command == "act!" ) {
        return RP_MASK;
    } else if ( command == "cmbt" ) {
        return COMBAT_MASK;
    } else if ( command == "comm" ) {
        return COMMUNICATION_MASK;
    } else if ( command == "ui  " ) {
        return UI_MASK;
    } else if ( command == "trvl" ) {
        return NAV_MASK;
    }
    return BROADCAST_MASK;
}

integer have_sfx()
{
    if ( sfxNode != NULL_KEY ) {
        if ( llKey2Name( sfxNode ) ) {
            return TRUE;
        } else {
            sfxNode == NULL_KEY;
        }
    }
    return FALSE;
}

list LINK_DELIMS = [ "^", "|" ];
string LINK_MSG_DELIM = "§";
string CHAT_MSG_DELIM = "|";

// -------------------------------------------------------------------------
// Communications channels

integer BROADCAST_MASK      = 0xFFF00000;
integer SCAN_MASK           = 0x1000000;
integer CONSTRUCT_MASK      = 0x2000000;
integer RP_MASK             = 0x4000000;
integer COMBAT_MASK         = 0x8000000;
integer COMMUNICATION_MASK  = 0x10000000;
integer PLUG_MASK           = 0x20000000;
integer NAV_MASK            = 0x40000000;
integer UI_MASK             = 0x80000000;

// -------------------------------------------------------------------------
// Manage position of HUD prims

list powerBar;

string HUDmode;

list showPowerModes =                   // Show focus bar in these modes
    [ "construct", "Act!", "Ring Plugin" ];
integer showPower = FALSE;              // Show the focus bar or not

show_power_bar( integer show ) {
    if ( showPower == show ) return;
    list barParams = [ PRIM_SIZE, <0.01, 0.01, 0.01>,
        PRIM_COLOR, ALL_SIDES, HILIGHT, 0.0 ];
    integer level;
    integer c = llGetListLength( powerBar );
    if ( show ) {
        barParams = [ PRIM_SIZE, <0.125, 0.125, 0.125>,
           PRIM_COLOR, ALL_SIDES, HILIGHT, 0.0,
           PRIM_TEXT, "", ZERO_VECTOR, 0.0 ];
    }
    list tail;
    while ( --c >= 0 ) {
        llSetLinkPrimitiveParamsFast( llList2Integer( powerBar, c ),
            barParams + tail );
    }
    showPower = show;
}

set_power_level( integer level, list prims )
{
    integer max = llGetListLength( prims );
    integer c = 0;
    do {
        if ( c < level ) {
            llSetLinkAlpha( llList2Integer( prims, c ), 0.67, ALL_SIDES );
        } else {
            llSetLinkAlpha( llList2Integer( prims, c ), 0.0, ALL_SIDES );
        }
    } while ( ++c < max );
}

list MODE_RING_CLOSED = [ PRIM_SIZE, <0.075, 0.075, 0.01>, 
    PRIM_CLICK_ACTION, CLICK_ACTION_IGNORE ];
list MODE_RING_OPEN = [ PRIM_SIZE, <0.2, 0.2, 0.01>, 
    PRIM_CLICK_ACTION, CLICK_ACTION_TOUCH ];

open_ring( list prims )
{
    close_ring( currentModePrims );
    integer c = llGetListLength( prims ) + 1;
    while ( c-- >= 0 ) {
        llSetLinkPrimitiveParamsFast( llList2Integer( prims, c ), MODE_RING_OPEN );
        llSetLinkAlpha( llList2Integer( prims, c ), 1.0, ALL_SIDES );
    }
    currentModePrims = prims;
}

close_ring( list prims )
{
    integer c = llGetListLength( prims ) + 1;
    while ( c-- >= 0 ) {
        llSetLinkAlpha( llList2Integer( prims, c ), 0.0, ALL_SIDES );
        llSetLinkPrimitiveParamsFast( llList2Integer( prims, c ), MODE_RING_CLOSED );
    }
    currentModePrims = [];
}

refresh_prims( list prims )
{
    integer c = llGetListLength( prims ) + 1;
    while ( c-- >= 0 ) {
        //llSetLinkPrimitiveParamsFast( llList2Integer( prims, c ),
        //     [ PRIM_TEXT, " ", ZERO_VECTOR, 0.0 ] );
    }
}

list SHADE_CLOSED = 
    [PRIM_SIZE, <0.01, 0.075, 0.075>, PRIM_COLOR, ALL_SIDES, ZERO_VECTOR, 0.0 ];
list SHADE_OPEN = 
    [PRIM_SIZE, <0.01, 0.2, 0.2>, PRIM_COLOR, ALL_SIDES, ZERO_VECTOR, 0.4 ];
shade_open( integer open )
{
    if ( open && contrast ) {
        llSetLinkPrimitiveParamsFast( shadePrim, SHADE_OPEN );
    } else {
        llSetLinkPrimitiveParamsFast( shadePrim, SHADE_CLOSED );
    }
}

integer moralePrim;
integer focusPrim;
integer rpPrim;
integer SMF = 2;                    // Status, Morale, Focus
integer STUNNED_MASK = 0x2;         // Status flag
integer RESTRAINED_MASK = 0x4;      // Status flag
integer DEFEATED_MASK = 0x8;        // Status flag

vector OPEN = <0.01, 0.15, 0.15>;
vector CLOSED = <0.01, 0.075, 0.075>;

bar_open( integer prim, integer open )
{
    if ( open ) {
        llSetLinkPrimitiveParamsFast( prim, [ PRIM_SIZE, OPEN ] );
    } else {
        llSetLinkPrimitiveParamsFast( prim, [ PRIM_SIZE, CLOSED ] );
    }
}

list mode_ring_init( list prims ) 
{
    prims = get_link_numbers( prims );
    close_ring( prims );
    return prims;
}

list get_link_numbers ( list names )
{
    integer c = llGetNumberOfPrims() + 1;
    integer i = -1;
    while ( c-- >= 0 ) {
        i = llListFindList( names, [ llGetLinkName( c ) ] );
        if ( i > -1 ) {
            names = llListReplaceList( names, [c], i, i );
        }
    }
    return names;
}

list get_prims_named( string prefix )
{
    list prims;
    integer c = llGetNumberOfPrims() + 1;
    integer i = -1;
    while ( c-- >= 0 ) {
        if ( llSubStringIndex( llGetLinkName( c ), prefix ) == 0  ) {
            prims += [ c ];
        }
    }
    return prims;
}

// -------------------------------------------------------------------------

list EXTERNAL_COMMANDS =                // List of commands to bre relayed from
                                        // untrusted sources
    [ "trgt", "aupd", "chrg", "read" ];

key sfxNode = NULL_KEY;                 // Key for the attachment that does
                                        // special effects
key remoteAuth = NULL_KEY;              // Remote commands authorized from

integer userChannel;
integer userHandle;                     // Listen handle for user channel
integer gestureHandle;
string powerSource;

// -------------------------------------------------------------------------

key errorSound = "6703a883-3bcc-b8fe-e113-f9695e96d341";

integer powerPrim;
integer POWER_FACE = 1;                 // Face where power levels are stored

integer FLAG_FACE = 1;

/* integer busy()
{
    vector params =llList2Vector( llGetLinkPrimitiveParams( rpPrim, 
        [ PRIM_COLOR, SMF ] ), 0 ) * 0xFF;
    integer flags = (integer)( params.x );
    return ( ( flags & ( STUNNED_MASK | DEFEATED_MASK ) ) ); // || 
//        !(integer)llGetAlpha( DIM_FACE ) );
}

set_busy( float time )
{
    if ( time > 0.1 ) {
        llSetAlpha( 0.0, DIM_FACE );
        llSetTimerEvent( time );
    } else {
        llSetAlpha( 1.0, DIM_FACE );
        llSetTimerEvent( 0.0 );
    }
} */

integer key2channel( key id )
{
    return -1 * (integer)( "0x" + llGetSubString(id, -10, -3));
}

vector rgb2hsv( vector rgb )
{
    vector hsv;

    float min = llListStatistics(LIST_STAT_MIN, [rgb.x,rgb.y,rgb.z]);
    float max = llListStatistics(LIST_STAT_MAX, [rgb.x,rgb.y,rgb.z]);
    hsv.z = max;

    float delta = max - min;
    if (delta == 0.) {
        delta = .00000001; // division by 0 kludge
    }

    if (max != 0.) {
        hsv.y = delta / max;
    }
    else {
        hsv.y = 0.;
        hsv.x = -1.;
        return hsv;
    }

    if (rgb.x == max) {
        hsv.x = (rgb.y - rgb.z) / delta;
    }
    else if (rgb.y == max) {
        hsv.x = 2 + (rgb.z - rgb.x) / delta;
    }
    else {
        hsv.x = 4 + (rgb.x - rgb.y) / delta;
    }

    hsv.x *= 60.;
    if (hsv.x < 0.) {
        hsv.x += 360.;
    }

    return hsv;
}

// ------------------------------------------------------------------------
// Targeting

// Maximum range to ping for targets
float PING_RANGE = 100.0;

// Ray cast for target
target_ping()
{
    vector camPos = llGetCameraPos();
    list hits = llCastRay( camPos,
        camPos + ( llRot2Fwd( llGetCameraRot() ) * PING_RANGE ),
        [ RC_MAX_HITS, 1, RC_DATA_FLAGS, RC_GET_ROOT_KEY ]
        );
    if ( llList2Integer( hits, -1 ) > 0 ) {
        llPlaySound( "46e2dd13-85b4-8c91-ab62-7d5c4dd16068", 0.5 );
        set_target( llList2Key( hits, 0 ) );
    } else if ( llList2Integer( hits, -1 ) == RCERR_CAST_TIME_EXCEEDED ) {
        llMessageLinked( LINK_ROOT, COMMUNICATION_MASK, "IM" + LINK_MSG_DELIM
            + "Raycast failure; possible SCR-243", llGetOwner() );
    }
}

set_target( key id )
{
    llLinksetDataWrite( "target", id );
}

// -------------------------------------------------------------------------
// HTTP command handling

string inURL;
key urlRequest;

http_post_request( key id, string body ) 
{
    key httpOwner = 
        (key)llGetHTTPHeader( id, "x-secondlife-owner-key" );
    key httpObject =
        (key)llGetHTTPHeader( id, "x-secondlife-object-key" );
    string sender = llGetHTTPHeader( id, "x-secondlife-owner-name" );
    string command = llDumpList2String( 
        llParseString2List( 
            llUnescapeURL( llGetHTTPHeader( id, "x-path-info" ) ), 
            ["/"], [] ), 
        LINK_MSG_DELIM );
    
    integer internal = ( httpOwner == llGetOwner() ) ||
        ( httpOwner == remoteAuth );

    // Non-owners can send communications
    if ( command == "send" ) {
        llMessageLinked( LINK_ROOT, COMMUNICATION_MASK,
            llDumpList2String( [ "comm", "rcvr", sender, body ],
                LINK_MSG_DELIM ),
            httpObject );
        llHTTPResponse( id, 200, "Sent." );
    } else if ( command == "report" ) {
        llMessageLinked( LINK_ROOT, COMMUNICATION_MASK,
            llDumpList2String( [ "comm", "rcvr", sender, body ],
                LINK_MSG_DELIM ),
            httpObject );
        llHTTPResponse( id, 200, "Sent" );
    } else if ( internal || 
        ( llListFindList( EXTERNAL_COMMANDS, [ command ] ) > -1 ) ) 
    { 
        // Owner & 1 authorized other can control ring
        if ( body ) {
            if ( command ) command += LINK_MSG_DELIM;
            command += llDumpList2String(
                llParseString2List( body, [ CHAT_MSG_DELIM ], [] ),
                LINK_MSG_DELIM );
        }
        integer linkChannel = get_link_channel( command );
        llMessageLinked( LINK_SET, linkChannel | 0,  command, httpObject );
        llHTTPResponse( id, 200, "OK" );
    } else { // Refuse anything else
        llHTTPResponse( id, 403, "Refused" );
    }
}

key get_URL()
{
    llReleaseURL( inURL );
    inURL = "";
    return llRequestURL();
}

// =========================================================================
// Event handlers
// =========================================================================

default // === Initialization ==============================================
{
    state_entry()
    {
        llSetLinkPrimitiveParamsFast( LINK_SET, [ PRIM_TEXT, "",
            ZERO_VECTOR, 0.0 ] );
        userChannel = key2channel( llGetOwner() );
        if ( llGetAttached() ) {
            state active;
        }
    }
    
    attach( key id )
    {
        if ( id ) {
            set_mode( llGetLinkName( currentMode ), currentMode );
            state active;
        }
    }
    
    state_exit()
    {
        llMessageLinked( LINK_SET, BROADCAST_MASK, "rset", llGetOwner() );
        llSleep( 1.0 );
        llWhisper( userChannel, "rset" );
        llSetTimerEvent( 0. );
        llListenRemove( userHandle );
        llListenRemove( gestureHandle );
    }
}

state active // === Monitoring for touches and chat =======================
{
    state_entry()
    {
        llSetLinkPrimitiveParamsFast( LINK_THIS,
            [ PRIM_SIZE, CENTER_SIZE,
            PRIM_TEXTURE, 0, logo, <1.0, 1.0, 0.0>, ZERO_VECTOR, 0.0,
            PRIM_COLOR, 0, NORMAL_COLOR, 1.0,
            PRIM_COLOR, 2, NORMAL_COLOR, 1.0 ] );
        userChannel = key2channel( llGetOwner() );
        llSetRot( llEuler2Rot( <0.0, -PI_BY_TWO, -PI_BY_TWO> ) );
        currentMode = -1;
        sfxNode = NULL_KEY;
        optionPrims = mode_ring_init( optionPrims );
        powerBar = get_prims_named( "power" );
        set_power_level( 0, powerBar );
        actPrims = mode_ring_init( actPrims );
        constructPrims = mode_ring_init( constructPrims );
        patrolPrims = mode_ring_init( patrolPrims );
        combatPrims = mode_ring_init( combatPrims );
        modePrims = get_link_numbers( modePrims );
        combatMode = llList2Integer( modePrims, 0 );
        sensorBarPrims = get_link_numbers( sensorBarPrims );
        // hotPrims = get_link_numbers( hotPrims );
        list miscPrims = get_link_numbers( [ "focus", "morale", "menu", 
           "construct", "Act!", "backshade" ] );
        focusPrim = llList2Integer( miscPrims, 0 );
        moralePrim = llList2Integer( miscPrims, 1 );
        menuPrim = llList2Integer( miscPrims, 2 );
        powerPrim = llList2Integer( miscPrims, 3 );
        rpPrim = llList2Integer( miscPrims, 4 );
        shadePrim = llList2Integer( miscPrims, 5 );
        
        bar_open( focusPrim, TRUE );
        bar_open( moralePrim, TRUE );
        shadeButtonPrim = llList2Integer( optionPrims, 1 );
        shade_open( FALSE );
        integer c = llGetListLength( modePrims ) + 1;
        while ( c-- >= 0 ) {
            llSetLinkColor( llList2Integer( modePrims, c ), 
                NORMAL_COLOR, 4 );
        }
        // set_hot_open( FALSE );        urlRequest = get_URL();
        userHandle = llListen( userChannel, "", NULL_KEY, "" );
        gestureHandle = llListen( 2814, "", llGetOwner(), "" );
        // set_busy( 0.0 );
        if ( llGetAttached() ) {
            llRequestPermissions( llGetOwner(), PERMISSION_TRACK_CAMERA |
                PERMISSION_TAKE_CONTROLS );
        }
        llOwnerSay( llGetScriptName() + " initialized; " +
            (string)llGetFreeMemory() + " bytes free." );
    }
    
    attach( key id )
    {
        if ( id ) {
            llSetRot( llEuler2Rot( < 0., -PI_BY_TWO, -PI_BY_TWO> ) );
            set_mode( llGetLinkName( currentMode ), currentMode );
            llRequestPermissions( id, PERMISSION_TRACK_CAMERA |
                PERMISSION_TAKE_CONTROLS );
            if ( powerSource ) {
                urlRequest = get_URL();
            }
        }
    }
    
    run_time_permissions( integer perm )
    {
        if ( perm & PERMISSION_TAKE_CONTROLS ) {
            llTakeControls( CONTROL_ML_LBUTTON | CONTROL_LBUTTON, 
                TRUE, TRUE );
        }
    }
    
    http_request(key id, string method, string body)
    {
        if ( urlRequest == id) {                // New URL handling
            urlRequest = NULL_KEY;
            if (method == URL_REQUEST_GRANTED ) {
                inURL = body;
                if ( llGetAttached() ) {
                    llMessageLinked( LINK_THIS, COMMUNICATION_MASK,
                        llDumpList2String( [ "store", powerSource + "-HUD-url", 
                                inURL ],
                            LINK_MSG_DELIM ),
                        llGetOwner() );
                }
            } else if (method == URL_REQUEST_DENIED) {
                llOwnerSay( "Long-range communications down. Error is: " 
                    + body);
            }
        } else if ( method == "POST" ) {
            http_post_request( id, body );
        } else if ( method == "GET" ) {
            llHTTPResponse( id, 200, llGetObjectName() + " - " + llGetObjectDesc() );
        }
    }
    
    changed( integer change )
    {
        if ( change & CHANGED_OWNER ) {
            llMessageLinked( LINK_SET, BROADCAST_MASK, "rset", NULL_KEY );
        } else if ( change & CHANGED_REGION ) {
            urlRequest = get_URL();
        } else if ( change & CHANGED_TELEPORT ) {
            // For some reason we have to sleep to keep in-region teleports
            // from causing a crash
            llSleep( 0.25 );
        }
    }

    touch_start( integer d )
    {
        llResetTime();
        ticks = 0;
        held = TRUE;
        llPlaySound( "aff7b933-8cb6-1584-9c06-edb0cc787912", 1.0 );
        string name = llGetLinkName( llDetectedLinkNumber( 0 ) );
        integer i = llListFindList( touchStartPrims, [ name ] );
        if ( i > -1 || sethot > 0 ) {
            float tickTime = llList2Float( touchStartPrims, i + 1 );
            if ( tickTime < 0.1 ) {
                tickTime = tick;
            }
            if ( tickTime < 0.1 ) {
                tickTime = 0.1;
            }
            parse_touch( llDetectedLinkNumber( 0 ), ticks );
            llSetTimerEvent( tickTime );
            ticks++;
            set_power_level( ticks, powerBar );
        }
    }
    
    timer()
    {
        if ( held && ticks < MAX_TICKS ) {
            ticks++;
            set_power_level( ticks, powerBar );
        /*} else if ( busy() ) {
            set_busy( FALSE ); */
        }
    }
    
    touch_end( integer d )
    {
        llSetTimerEvent( 0. );
        held = FALSE;
        if ( !ticks ) {
            if ( llGetTime() >= 0.5 ) {
                ticks = TRUE;
            }
        }
        if ( sethot > 0 ) {
            llSetLinkPrimitiveParams( sethot,
                [ PRIM_DESC, llGetLinkName( llDetectedLinkNumber(0) ) ] );
            llSetLinkColor( sethot, <1, 1, 1>, ALL_SIDES );
            sethot = FALSE;
        } else {
            parse_touch( llDetectedLinkNumber( 0 ), ticks );
        }
        ticks = FALSE;
        set_power_level( 0, powerBar );
        refresh_prims( optionPrims + actPrims + patrolPrims 
            + combatPrims + constructPrims );
    }
    
    listen (integer channel, string name, key id, string m)
    {
        integer internal = FALSE;
        
        if ( debugging_on ) {
            llOwnerSay( llGetScriptName() + " heard " + name + " say " + m );
        }
        
        // Security checks here.  Make sure this is either for me, from my
        // object, or from my override owner
        key from = llGetOwnerKey( id );
        internal = ( from == llGetOwner() ) ||
            ( from == remoteAuth );
        
        if ( llGetSubString( m, 0, 35 ) == (string)llGetOwner() ) {
            m = llGetSubString( m, 37, -1 );
        } else if ( !internal ) {
            return;
        }
        
        // Pass on the command if it passes security
        list parsed = llParseStringKeepNulls( m, [ CHAT_MSG_DELIM ], [] );
        string cmd = llToLower( llList2String( parsed, 0 ) );
        
        if ( internal ||
            ( llListFindList( EXTERNAL_COMMANDS, [ cmd ] ) > -1 ) ||
            id == sfxNode )
            // Can't get owner key of sfxNode as it detaches
        {
            // llOwnerSay( llGetScriptName() + " accepted " + m + " from " + llKey2Name( id ));
            if ( cmd == "busy" ) {
                // set_busy( (float)llList2String( parsed, 1 ) );
                return;
            } else if ( cmd == "sfxsyn" ) {
                llWhisper( userChannel, llDumpList2String(
                    [ "sfxack", id ], CHAT_MSG_DELIM ) );
            } else if ( cmd == "sfxsynack" || cmd == "repower" ) {
                sfxNode = id;
                llMessageLinked( LINK_SET, BROADCAST_MASK, 
                    "pwr+", llGetOwner() );
                float band = (float)llList2String( parsed, 1 ) / 0xFF;
                float rezParams = (float)llList2String( parsed, 2 ) / 0xFF;
                powerSource = llList2String( parsed, 3 );
                logo = (key)llList2String( parsed, 4 );
                float hue = (float)llList2String( parsed, 5 );
                HILIGHT = (vector)llList2String( parsed, 6 );

                vector oldColor = llGetColor( FLAG_FACE );
                llSetColor( <hue, oldColor.y, oldColor.z>, FLAG_FACE );
                llSetLinkPrimitiveParamsFast( LINK_ROOT,
                    [ PRIM_SIZE, CENTER_SIZE,
                    PRIM_TEXTURE, 0, logo, <1.0, 1.0, 0.0>, ZERO_VECTOR, 0.0,
                    PRIM_COLOR, DIM_FACE, HILIGHT, 1.0,
                    PRIM_COLOR, LIT_FACE, NORMAL_COLOR, 0.0 ] );
                llSetLinkColor( powerPrim, <band, rezParams, 0.0>,
                    POWER_FACE );
                llMessageLinked( powerPrim, CONSTRUCT_MASK, 
                    llDumpList2String(
                        [ "chrg", "source" ] + llList2List( parsed, 7, -1 ),
                        LINK_MSG_DELIM ), 
                    id );
                if ( cmd == "sfxsynack" ) {
                    llMessageLinked( rpPrim, RP_MASK, llDumpList2String(
                            ["act!", "a!trt", llGetOwner(), 
                                UI_MASK | 1, powerSource],
                            ":" ),
                        llGetKey() );
                    urlRequest = get_URL();
                    llOwnerSay( name + " powered by " + powerSource + "." );
                }
                if ( cmd == "repower" ) {
                    set_mode( "", currentMode );
                }
            } else if ( cmd == "sfxfin" ) { // && id == sfxNode ) {
                sfxNode == NULL_KEY;
                llOwnerSay("Power source missing; active functions shut off.");
                set_mode( llGetLinkName( currentMode ), currentMode );
            } else if ( cmd == "ping" ) {
                target_ping();
            } else {
                //llOwnerSay( llGetScriptName() + " sent on " +
                //    llDumpList2String( parsed, LINK_MSG_DELIM ) );
                llMessageLinked( LINK_SET, BROADCAST_MASK,
                    llDumpList2String( parsed, LINK_MSG_DELIM ), id );
            }
        }
    }
    
    link_message( integer source, integer flag, string message, key id )
    {
        list msg;
        string cmd;
    
        // llOwnerSay( llGetScriptName() + ":" + llGetLinkName( source ) + ": " + message );
        
        if ( flag & UI_MASK ) {
            cmd = llGetSubString( message, 0, 3 );
            flag = flag & ~BROADCAST_MASK;
            // llOwnerSay( (string)flag + ": " + message );
            if ( cmd == "tick" ) {
                tick = (float)llGetSubString( message, 5, -1 );
            } else if ( cmd == "diag" ) {
                llWhisper( 0, "/me INPUT" +
                    "\nChannel " + (string)userChannel + 
                    "\nURL: " + inURL +
                    "\n" + (string)llGetFreeMemory() + " bytes free."
                    );
            } else if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "shad" ) {
                contrast = !contrast;
                if ( contrast ) {
                    llSetLinkColor( shadeButtonPrim, llGetColor( 0 ), 
                        ALL_SIDES );
                } else {
                    llSetLinkColor( shadeButtonPrim, llGetColor( 2 ), 
                        ALL_SIDES );
                }
                shade_open( contrast );
            //} else if ( cmd == "busy" ) {
            //    set_busy( (float)llGetSubString( message, 5, -1 ) );
            } else if ( cmd == "glow" && have_sfx() ) {
                if ( flag & 0xFF ) {
                    llWhisper( userChannel, llDumpList2String(
                        [ "glow", "level", flag & 0xFF ], CHAT_MSG_DELIM ) );
                }
            } else if ( cmd == "auth" ) {
                remoteAuth = id;
                if ( remoteAuth != llGetOwner() ) {
                    llOwnerSay( "secondlife:///app/agent/" + (string)remoteAuth + 
                        "/inspect can now send commands to your ring." );
                }
            } else if ( cmd == "rdrw" ) {
                refresh_prims( optionPrims + actPrims + patrolPrims 
                    + combatPrims + constructPrims );
            } else if ( cmd == "char" ) { 
                llWhisper( userChannel, "rsyn" );
            } else if ( cmd == "chmd" ) {
                cmd = llGetSubString( message, 5, -1 );
                integer i = llListFindList( modes, [ cmd ] );
                if ( i > -1 ) {
                    integer j = llList2Integer( modePrims, i );
                    if ( j != currentMode ) {
                        set_mode( llGetLinkName( j ), j );
                    }
                }
            } else if ( cmd == "stht" ) {
                if ( sethot < 1 ) {
                    llOwnerSay( "Setting hot button" );
                    sethot = -1;
                } else {
                    sethot = FALSE;
                }
            } else if ( flag == 1 ) { 
                if ( cmd == "FAIL" ) {
                    sfxNode = NULL_KEY;
                    llOwnerSay("You do not have the " + powerSource 
                        + " trait; active abilities disabled." );
                    llWhisper( userChannel, llDumpList2String(
                        [ "douse" ], CHAT_MSG_DELIM ) );
                } else if ( cmd == "SUCCESS" ) {
                    llWhisper( userChannel, llDumpList2String(
                        [ "ignite" ], CHAT_MSG_DELIM ) );
                }
            }
        }
    }
    
    control( key id, integer held, integer change )
    {
        if ( currentMode != combatMode ) {
            if ( change & CONTROL_LBUTTON ) {
                if ( currentMode > -1 ) {
                    if ( held ) {
                        llResetTime();
                    } else if ( llGetAndResetTime() > 0.25 ) {
                        target_ping();
                    }
                }
            }
            if ( ( ~held & change & CONTROL_ML_LBUTTON ) )
            {
                target_ping();
            }
        }
    }
}
