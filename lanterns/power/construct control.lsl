// =========================================================================
// Construct controller                                                    \
// By Jack Abraham                                                      \__
// =========================================================================

key activeConstruct;                    // Currently active construct
                                        // (rezzed in-world)
integer userChannel;                    // HUD-construct control channel
list constructs;                        // Cached list of constructs

list attachments;                       // Constructs attached to me

integer POWER_FACE = 1;                 // Face where power levels are stored
string sticky = "";                     // Sticky prefix
float TIMER = 2.0;                      // Event timer

float chargeRatio = 1.0;                // Different recharge types
integer chargeType = 1;
integer CHARGE = 1;
integer DAILY = 2;
integer INTERNAL = 3;

list ENERGY_TYPES =                     // Types of energy
    [ "", "rage", "desire", "fear", "will", "hope", "compassion", "love",
    "death", "life", "light", "darkness", "sound", "force", "psi", "fire",
    "ice", "plasma" ];
    
// -------------------------------------------------------------------------
// Commands processing

obj_commands( list msg, integer power, key id )
{
    string cmd = llList2String( msg, 0 );
    // llOwnerSay( llGetScriptName() + llList2CSV( msg ) );
    if ( cmd == "menu" ) {
        object_menu( FALSE );
    } else if ( cmd == "mmnu" ) {
        type = "";
        sticky = "";
        object_menu( FALSE );
    } else if ( cmd == "smnu" ) { // Submenu
        type = llList2String( msg, 1 );
        sticky = "";
        object_menu( FALSE );
    } else if ( cmd == "stmn" ) { // Sticky menu
        type = llList2String( msg, 1 );
        if ( type == "off" ) {
            sticky = "";
            type = "";
        } else {
            sticky = type;
            object_menu( TRUE );
        }
    } else if ( cmd == "actv" ) {
        set_active_construct( (key)llList2String( msg, 1 ) );
    } else if ( cmd == "die" ) {
        send_construct_msg( [ "die" ] );
        clear_active_construct_msg();
    } else if ( cmd == "all die" ) {
        send_global_construct_msg( [ "die" ] );
        clear_active_construct_msg();
    } else if ( cmd == "life" ) {
        if ( power ) {
            set_life( activeConstruct, power );
        }
    } else if ( cmd == "wear" ) {
        attachments += id;
    } else if ( cmd == "amnu" ) {
        attachment_menu();
        llSetTimerEvent( TIMER );
    } else if ( cmd == "cmnu" ) {
        send_construct_msg( [ "cmnu" ] );
    } else if ( cmd == "wpnopt" ) {
        llWhisper( userChannel, llDumpList2String(
            [ llGetOwner(), "wpnopt" ], CHAT_MSG_DELIM ) );
        llSetTimerEvent( TIMER );
    } else if ( cmd == "refresh" ) {
        refresh();
    }
}

integer powerPrim;

set_life( key construct, integer power ) {
    float mass = llGetObjectMass( construct );
    float drain = llSqrt( mass ) * power * chargeRatio / 10000.0;
    if ( drain ) {
        float powerLevel = (float)llLinksetDataRead( "power" );
        if ( powerLevel > drain || chargeType == DAILY ) {
            if ( chargeType != DAILY ) {
                llLinksetDataWrite( "power", (string)( powerLevel - drain ) );
            }
            send_construct_msg( [ "life", 144.0 * 
                (llPow( 10.0, (float)power / 5.0 ) - 1.0) ] );
        } else {
            llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String(
                [ "IM", "Insufficient power remaining" ],
                LINK_MSG_DELIM ), llGetOwner() );
        }
    }
}
// -------------------------------------------------------------------------
// Voice command

list SEPARATORS = [ " " ];
list PREFIX = [ "ring ", "ring,", "ring:" ];

string voice_command( string msg )
{
    msg = llToLower( msg );
    list words = llParseString2List( msg, SEPARATORS, [] );
    if ( llListFindList( PREFIX, [ llList2String( words, 0 ) ] ) > -1 ) {
        words = llList2List( words, 1, -1 );
    }
    if ( llList2String( words, 0 ) == "power" ) {
        if ( llList2String( words, 1 ) == "levels" ) {
            return "chrg" + LINK_MSG_DELIM + "level";
        }
    }
    string lastWord = "";
    integer wc = llGetListLength( words );
    if ( wc > 1 ) {
        lastWord = llToLower( llList2String( words, wc - 1 ) );
    }
    string statement = llDumpList2String( words, " " );
    string command = can_rez( statement );
    if ( command ) return command;
    string type = llDumpList2String( llList2List( words, 0, -2), " " );
    if ( lastWord == "shield" ) {
        if ( llGetInventoryType( "shield:" + type ) == INVENTORY_OBJECT ) {
            return llDumpList2String( [ "objt", "load", "shield:" + type ],
                LINK_MSG_DELIM );
        }
    }
    command = can_rez( lastWord + ":" + 
            type );
    if ( command ) return command;
    command = search_for_rez( statement );
    if ( command ) return command;
    command = search_for_rez_partial( statement );
    return command;
}

string can_rez( string item )
{
    if ( llGetInventoryType( item ) == INVENTORY_OBJECT ) {
        return llDumpList2String( [ "objt", "load", item ], LINK_MSG_DELIM );
    }
    return "";
}

string search_for_rez( string item ) {
    item = llToLower( item );
    integer c = llGetInventoryNumber( INVENTORY_OBJECT );
    integer i;
    string name;
    list words;
    for ( i=0; i < c; ++i ) {
        name = llToLower( llGetInventoryName( INVENTORY_OBJECT, i ) );
        words = llParseStringKeepNulls( name, [ ":" ], [] );
        if ( item == llList2String( words, -1 ) ) {
            return llDumpList2String( [ "objt", "load", 
                llGetInventoryName( INVENTORY_OBJECT, i ) ],
                LINK_MSG_DELIM );
        }
    }
    return "";
}

string search_for_rez_partial( string item ) {
    item = llToLower( item );
    integer c = llGetInventoryNumber( INVENTORY_OBJECT );
    integer i;
    string name;
    list words;
    for ( i=0; i < c; ++i ) {
        name = llToLower( llGetInventoryName( INVENTORY_OBJECT, i ) );
        words = llParseStringKeepNulls( name, [ ":" ], [] );
        if ( llSubStringIndex( llList2String( words, -1 ), item ) > -1 ) {
            return llDumpList2String( [ "objt", "load", 
                llGetInventoryName( INVENTORY_OBJECT, i ) ],
                LINK_MSG_DELIM );
        }
    }
    return "";
}

// -------------------------------------------------------------------------
// Permissions checking

integer DIM_FACE = 0;
integer SMF = 2;                    // Status, Morale, Focus
integer STUNNED_MASK = 0x2;         // Status flag
integer DEFEATED_MASK = 0x8;        // Status flag

integer busy()
{
    vector params =llList2Vector( llGetLinkPrimitiveParams( rpPrim, 
        [ PRIM_COLOR, SMF ] ), 0 ) * 0xFF;
    integer rootBusy = llList2Float( llGetLinkPrimitiveParams( LINK_ROOT,
        [ PRIM_COLOR, DIM_FACE ] ), 1 ) < 0.5;
    integer flags = (integer)( params.x );
    return ( ( flags & ( STUNNED_MASK | DEFEATED_MASK ) ) || 
        rootBusy );
}

integer check_scripts( integer flags ) {
    if ( flags & PARCEL_FLAG_ALLOW_SCRIPTS )
        return TRUE;
    else if ( flags & PARCEL_FLAG_ALLOW_GROUP_SCRIPTS ) {
        key parcelGroup = llList2Key( 
                llGetParcelDetails( llGetPos(), [ PARCEL_DETAILS_GROUP ] )
                , 0 );
        key group = llList2Key(
            llGetObjectDetails( llGetKey(), [ OBJECT_GROUP ] )
            , 0 );
        if ( parcelGroup == group ) {
            return TRUE;
        }
    } 
    vector here = llGetPos();
    if ( llGround( here ) < here.z - 50.0 ) {
        return TRUE;
    }
    return FALSE;
}

integer check_perms() {
    if ( llOverMyLand( llGetOwner() ) ) return TRUE;

    integer parcel = llGetParcelFlags( llGetPos() );

    if ( !check_scripts( parcel ) ) return FALSE;

    if ( PARCEL_FLAG_ALLOW_CREATE_OBJECTS  & parcel )
        return TRUE;
    else if ( PARCEL_FLAG_ALLOW_CREATE_GROUP_OBJECTS & parcel ) {
        key parcelGroup = llList2Key( 
                llGetParcelDetails( llGetPos(), [ PARCEL_DETAILS_GROUP ] )
                , 0 );
        key group = llList2Key(
            llGetObjectDetails( llGetKey(), [ OBJECT_GROUP ] )
            , 0 );
        if ( parcelGroup == group ) {
            return TRUE;
        }
    }
    return FALSE;
}

// -------------------------------------------------------------------------
// Menuing

string prefix;
string type;

object_menu( integer sticky )
{
    list powerProperties = llGetLinkPrimitiveParams( powerPrim,
        [ PRIM_COLOR, POWER_FACE ] );
    float powerLevel = (float)llLinksetDataRead( "power" );
    if ( powerLevel <= 0.0 ) return;
    
    vector powerAttrib = llList2Vector( powerProperties, 0 ) * 0xFF;
    integer powerParam = (integer)powerAttrib.y;

    if ( constructs == [] ) refresh();
    prefix = type;
    integer prefixLength = llStringLength( type );
    list menuItems;
    list menuCommands;
    if ( type != "" ) {
        if ( !sticky ) {
            menuItems = [ "MAIN" ];
            menuCommands = [ llDumpList2String( ["objt", "mmnu"], 
                LINK_MSG_DELIM ) ];
        }
        ++prefixLength;
    }
    integer i;
//    integer c = llGetInventoryNumber( INVENTORY_OBJECT );
    integer c = llGetListLength( constructs );
    string menuName;
    string objName;
    list parsed;
    for ( i=0; i < c; ++i ) {
//        objName = llGetInventoryName( INVENTORY_OBJECT, i );
        objName = llList2String( constructs, i );
        if ( ( type == "" ) || 
                ( llGetSubString( objName, 0, prefixLength - 1 ) 
                  == type + ":" ) ) 
        {
    
            menuName = llGetSubString( objName, prefixLength, -1 );
            parsed = llParseString2List( menuName, [":"], [] );
            if ( llGetListLength( parsed ) > 1 ) {
                if ( llListFindList( ENERGY_TYPES, [ llList2String( parsed, 0 ) ] )
                    < 0 )
                {
                    menuName = "> " + llList2String( parsed, 0 );
                   if ( llListFindList( menuItems, [ menuName ] ) 
                            == -1 ) 
                    {
                        menuItems += menuName;
                        menuCommands += llDumpList2String(
                            [ "objt", "smnu", type, 
                                llList2String( parsed, 0 ) ],
                            LINK_MSG_DELIM );
                    }
                }
            } else {
                menuItems += menuName;
                menuCommands += llDumpList2String( [ "objt", "load", objName ],
                    LINK_MSG_DELIM );
            }
        }
    }
    string cmd = "menu";
    if ( sticky ) cmd = "stmn";
    string title = "Constructs";
    if ( prefix ) title += ": " + type;
    if ( powerParam & 0x10 ) title += "\n(peacekeeper)";
    if ( menuItems ) {
        llMessageLinked( menuPrim, OBJ_MASK, 
            llDumpList2String( [ cmd, 
                title, 
                llList2CSV( menuItems ), 
                llList2CSV( menuCommands ) ],
                LINK_MSG_DELIM ),
            llGetOwner() );
    }
}

// Menu of currently worn attachments

attachment_menu()
{
    integer c = llGetListLength( attachments );
    list menuItems;
    list menuCommands;
    string item;
    
    while ( --c >= 0 ) {
        if ( llKey2Name( llList2Key( attachments, c ) ) ) {
            menuItems += llKey2Name( llList2Key( attachments, c ) );
            menuCommands += llDumpList2String( [ "objt", "actv", 
                llList2Key( attachments, c ) ] , LINK_MSG_DELIM );
        } else {
            attachments = llDeleteSubList( attachments, c, c );
        }
    }
    
    if ( menuItems != [] ) {
        llMessageLinked( menuPrim, OBJ_MASK, 
            llDumpList2String( [ "menu", 
                "Attachments", 
                llList2CSV( menuItems ), 
                llList2CSV( menuCommands ) ],
                LINK_MSG_DELIM ),
            llGetOwner() );
    }
}

add_attachment( key attachment )
{
    integer c = llGetListLength( attachments );
    while ( --c >= 0 ) {
        if ( llKey2Name( llList2Key( attachments, c ) ) == "" ) {
            attachments = llDeleteSubList( attachments, c, c );
        }
    }
    attachments = [] + attachments + [ attachment ];
}
            
refresh()
{
    integer i;
    integer c = llGetInventoryNumber( INVENTORY_OBJECT );
    constructs = [];
    for ( i=0; i < c; ++i ) {
        constructs += llGetInventoryName( INVENTORY_OBJECT, i );
        
    }
}

// -------------------------------------------------------------------------
// Construct control

string GLOBAL_KEY =                     // UUID for commands to all constructs
    "1c7600d6-661f-b87b-efe2-d7421eb93c86";

send_construct_msg( list msg )
{
    if ( activeConstruct ) {
        llRegionSayTo( activeConstruct, userChannel, 
            llDumpList2String( [ activeConstruct ] + msg, CHAT_MSG_DELIM ) );
    }
}

send_global_construct_msg( list msg )
{
    llRegionSay( userChannel, 
        llDumpList2String( [ GLOBAL_KEY ] + msg, CHAT_MSG_DELIM ) );
}

set_active_construct( key id )
{
    clear_active_construct_msg();
    if ( id ) {
        activeConstruct = id;
        llMessageLinked( statusPrim, COMM_MASK,
            llDumpList2String( [ "status", "Construct: " 
                + llKey2Name( id ), 15.0 ],
                LINK_MSG_DELIM ),
            llGetOwner() );
        llSetTimerEvent( TIMER );
    }
}

clear_active_construct_msg()
{
    llMessageLinked( statusPrim, COMM_MASK,
        llDumpList2String( [ "unstatus", "Construct: " ],
            LINK_MSG_DELIM ),
        llGetOwner() );
    llSetTimerEvent( 0. );
}

check_active_construct()
{
    if ( llKey2Name( activeConstruct ) == "" && activeConstruct != NULL_KEY) 
    {
        clear_active_construct_msg();
        activeConstruct = NULL_KEY;
    }
}

// -------------------------------------------------------------------------
// Targeting

integer targetPrim = LINK_ROOT;

key get_target()
{
    return llLinksetDataRead( "target" );
}

vector LIT = <0.5, 1.0, 0.5>;
vector DIM = <1.0, 1.0, 1.0>;

set_prim_lit( integer prim, integer lit )
{
    if ( lit ) {
        llSetLinkColor( prim, LIT, ALL_SIDES );
    } else {
        llSetLinkColor( prim, DIM, ALL_SIDES );
    }
}

// -------------------------------------------------------------------------

integer menuPrim = LINK_SET;
integer statusPrim = LINK_ROOT;
integer camPrim = 0;

integer find_prim_named( string name )
{
    integer i = llGetNumberOfPrims();
    name = llToLower( name );
    while( --i > 0 ) {
        if ( llToLower( llGetLinkName( i ) ) == name ) {
            return i;
        }
    }
    return LINK_SET;
}

integer key2channel( key id )
{
    return -1 * (integer)( "0x" + llGetSubString(id, -10, -3));
}

// -------------------------------------------------------------------------

string LINK_MSG_DELIM = "§";
string CHAT_MSG_DELIM = "|";

integer BROADCAST_MASK      = 0xFFF00000;
integer OBJ_MASK            = 0x2000000;
integer COMM_MASK           = 0x10000000;
integer UI_MASK             = 0x80000000;
integer RP_MASK             = 0x4000000;
integer COMBAT_MASK         = 0x8000000;

integer rpPrim = LINK_SET;
integer combatPrim = LINK_SET;

integer POWER_LEVEL_MASK    = 0xF;

// =========================================================================
// Configuring

default
{
    state_entry()
    {
        menuPrim = find_prim_named( "menu" );
        targetPrim = find_prim_named( "target" );
        userChannel = key2channel( llGetOwner() );
        powerPrim = find_prim_named( "construct" );
        combatPrim = find_prim_named( "combat" );
        rpPrim = find_prim_named( "Act!" );
        llListen( 0, "", llGetOwner(), "" );
        //llWhisper( DEBUG_CHANNEL, "Construct controls initialized; " 
        //    + (string)( (integer)( 100 * llGetFreeMemory() / 65536 ) ) 
        //    + "% capacity remaining." );
    }
    
    link_message( integer source, integer flag, string message, key id )
    {
        if ( flag & OBJ_MASK ) {
            string cmd = llGetSubString( message, 0, 3 );
            
            // llOwnerSay( "[" + llGetScriptName() + ":" + (string)source + ":" + llKey2Name(id) + ":object]" + message );        
            
            if ( cmd == "objt" )
            {
                list msg = llParseString2List( message, 
                    [LINK_MSG_DELIM], [] );
                obj_commands( llList2List( msg, 1, -1 ), 
                    flag & POWER_LEVEL_MASK, id );
            } else if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "chrg" ) {
                list msg = llParseString2List( message, 
                    [LINK_MSG_DELIM], [] );
                if ( llList2String( msg, 1 ) == "source" ) {
                    chargeType = (integer)llList2String( msg, 2 );
                    chargeRatio = (float)llList2String( msg, 3 );
                }
            } else if ( cmd == "mode" ) {
                sticky = "";
                if ( llGetSubString( message, 5, -1 ) == "construct" ) {
                    prefix = "";
                    type = "";
                    if ( activeConstruct ) {
                        if ( llKey2Name(activeConstruct) ) {
                            set_active_construct( activeConstruct );
                        }
                    } else {
                        clear_active_construct_msg();
                    }
                }
            } else if ( cmd == "soca" ) {
                key obj = (key)llGetSubString( message, 5, -1 );
                key creator = llList2Key(
                    llGetObjectDetails( obj, [ OBJECT_CREATOR ] ), 0 );
                if ( creator == llGetOwner() ) {
                    obj_commands( [ "actv", obj ], 
                        flag & POWER_LEVEL_MASK, id );
                }
            } else if ( cmd == "trgt" ) {
                send_global_construct_msg( 
                    llParseString2List( message, [ LINK_MSG_DELIM ], [] )
                    );
            } else if ( cmd == "fmem" ) {
                llMessageLinked( source, llGetFreeMemory(), "fmem", id );
            } else if ( cmd == "diag" ) {
                llWhisper( 0, "/me CONSTRUCT CONTROLS" +
                    "\n" + (string)llGetFreeMemory() + " bytes free."
                    + "\nActive construct: " + (string)activeConstruct
                    );
            }
        }
    }
        
    listen( integer channel, string who, key id, string msg )
    {
        if ( llListFindList( PREFIX, 
            [ llToLower( llGetSubString( msg, 0, 4 ) ) ] )
            > -1 || channel ) 
        {
            string cmd = voice_command( msg );
            if ( cmd ) {
                llMessageLinked( LINK_THIS, OBJ_MASK, cmd, id );
            } else {
                llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String(
                    [ "IM", "Unable to parse command." ], LINK_MSG_DELIM ), 
                    id );
            }
        }
    }
    
    object_rez( key construct )
    {
        llMessageLinked( combatPrim, COMBAT_MASK, "cmbt" + LINK_MSG_DELIM 
            + "action", llGetOwner() );
        llSleep( 0.05 );
        string creator = (string)llList2Key( llGetObjectDetails( construct,
            [ OBJECT_CREATOR ] ), 0 );
        set_active_construct( construct );
        key target = get_target();
        if ( target ) {
            llSetObjectDesc( "trgt:" + (string)target );
            llSleep( 0.1 );
            send_construct_msg( [ "trgt", target ] );
        } else {
            llSetObjectDesc( "" );
            llSensor( "", NULL_KEY, AGENT, 20.0, PI / 3.0 );
        }
    }

    sensor( integer d )
    {
        send_construct_msg( [ "trgt", llDetectedKey(0) ] );
    }
                
    no_sensor()
    {
        send_construct_msg( [ "trgt", NULL_KEY ] );
    }

    timer()
    {
        check_active_construct();
    }
    
    state_exit()
    {
        activeConstruct = NULL_KEY;
        clear_active_construct_msg();
        llSetTimerEvent( 0. );
    }
}

// Copyright ©2023 Jack Abraham and player, all rights reserved
// Contact Guardian Karu in Second Life for distribution rights