// ===========================================================================
// Mystic Gems Scanner                                                      \
// By Jack Abraham                                                       \__
// ===========================================================================

integer LIT_FACE = 0;
integer DIM_FACE = 2;

integer userChannel;
float power;
vector basecolor;
float range = 96.;
string menuHeader = "SCANNER";
integer mode = AGENT;                   // What to scan for
integer LAND = -1;                      // Fake sensor mode for land scan
integer active = FALSE;
integer reporting = FALSE;
key request;
key owner;

list reportPrefix;                      // Static parcel scan data
key parcel;                             // Last parcel scanned

integer SCAN_MASK           = 0x1000000;
integer COMMUNICATION_MASK  = 0x10000000;

list lines;                             // What to send to the screen
integer comm = LINK_ROOT;               // Where are the prims?
integer status = LINK_ALL_OTHERS;
integer bioPrim;
integer massPrim;
integer energyPrim;
integer scriptPrim;
integer landPrim;
integer filterPrim;
integer menuPrim;
integer targetPrim;

list agentData;
key query;
integer beam = FALSE;
integer filter = FALSE;

integer phoenixHandle;
integer firestormHandle;
integer PHOENIX = -777777777;               // Old Phoenix data channel
integer FIRESTORM = 777777777;              // Firestorm data channel
key PHOENIX_UPDATE =                        // Triggering this sound causes 
    "76c78607-93f9-f55a-5238-e19b1a181389"; // Phoenix radar to resend all

key group;                                  // My group

list DELIMIT = [ "§", ":", "|" ];           // Communications delimiters
string LINK_MSG_DELIM = "§";

float PRF = 10.0;                           // Pulse Repetition Frequency

sensorStart()
{
    active = TRUE;
    llSensorRemove();
    if ( range > 96. ) range = 96.;
    if ( mode == AGENT ) {
//        phoenixHandle = llListen( PHOENIX, "", NULL_KEY, "" );
//        firestormHandle = llListen( FIRESTORM, "", NULL_KEY, "" );
//        llTriggerSound( PHOENIX_UPDATE, 1.0 );
    } else if ( phoenixHandle || firestormHandle ) {
        llListenRemove( phoenixHandle );
        llListenRemove( firestormHandle );
        phoenixHandle = FALSE;
        firestormHandle = FALSE;
    } else if ( mode == LAND ) {
        reportPrefix = [];
        parcel = NULL_KEY;
    }
    report_mode();
    llSetTimerEvent( PRF );
    scan();
}

report_mode()
{
    linkMessage( status, [ "clear screen" ] );
    if ( mode == AGENT ) {
        set_lit( bioPrim, TRUE );
        set_lit( energyPrim, FALSE );
        set_lit( massPrim, FALSE );
        set_lit( scriptPrim, FALSE );
        set_lit( landPrim, FALSE );
    } else if ( mode == ( ACTIVE | SCRIPTED ) ) {
        set_lit( bioPrim, FALSE );
        set_lit( energyPrim, TRUE );
        set_lit( massPrim, FALSE );
        set_lit( scriptPrim, FALSE );
        set_lit( landPrim, FALSE );
    } else if ( mode == ( ACTIVE | PASSIVE ) ) {
        set_lit( bioPrim, FALSE );
        set_lit( energyPrim, FALSE );
        set_lit( massPrim, TRUE );
        set_lit( scriptPrim, FALSE );
        set_lit( landPrim, FALSE );
    } else if ( mode == ( SCRIPTED ) ) {
        set_lit( bioPrim, FALSE );
        set_lit( energyPrim, FALSE );
        set_lit( massPrim, FALSE );
        set_lit( scriptPrim, TRUE );
        set_lit( landPrim, FALSE );
    } else if ( mode == LAND ) {
        set_lit( bioPrim, FALSE );
        set_lit( energyPrim, FALSE );
        set_lit( massPrim, FALSE );
        set_lit( scriptPrim, FALSE );
        set_lit( landPrim, TRUE );
    }
}

scan()
{
    if ( mode != AGENT ) {
        llSensor( "", NULL_KEY, mode, range, PI );
    }
    return;
}

list parcel_scan()
{
    key thisParcel = llList2Key( llGetParcelDetails( llGetPos(),
        [ PARCEL_DETAILS_ID ] ), 0 );
    if ( thisParcel != parcel ) {
        parcel = thisParcel;
        vector pos = llGetPos();
        reportPrefix = [  llList2String( llGetParcelDetails( pos,
            [ PARCEL_DETAILS_NAME ] ), 0 ), llGetRegionName(),
            "Max Prims: " + (string)llGetParcelMaxPrims( pos, TRUE ) ];
    }
    return reportPrefix; 
}

integer scan_commands( list parsed )
{
    string cmd = llList2String( parsed, 1 );
    if ( cmd == "off" ) {
        active = FALSE;
    } else if ( cmd == "on" ) {
        active = TRUE;
    } else if ( cmd == "report" ) {
        reporting = TRUE;
    } else if ( cmd == "mode" ) {
        integer newFlags;
        string newmode = llList2String( parsed, 2 );
        if ( newmode == "bio" )
            newFlags = AGENT;
        else if ( newmode == "energy" )
            newFlags = ACTIVE | SCRIPTED;
        else if ( newmode == "mass" )
            newFlags = ACTIVE | PASSIVE;
        else if ( newmode == "scripts" )
            newFlags = SCRIPTED;
        //else if ( newmode == "sim" )
        //    newFlags = LAND;
        if ( newFlags == mode ) {
            active = FALSE;
        } else {
            mode = newFlags;
            active = TRUE;
            sensorStart();
        }
    } else if ( cmd == "menu" ) {
        llMessageLinked( menuPrim, SCAN_MASK,
            llDumpList2String( [ "menu", "Sensors",
                llList2CSV( ["Bioscan", "Energy Scan", "Mass Scan", 
                    "Script Scan", "Off",
                    " ",
                    "Target Detail", "Area Detail", "My Detail",
                    " ",
                    "Display Names", "⚡ Memory", "☢ Memory"
                    ] ),
                llList2CSV( ["scan§mode§bio", "scan§mode§energy", 
                    "scan§mode§mass", "scan§mode§scripts", "scan§off", 
                    "-", 
                    "sens§probe", "sens§land",
                    "sens§probe§" + (string)llGetOwner(),
                    "-",
                    "display names", "lot mem", "omg mem"
                     ] ) ],
                LINK_MSG_DELIM ),
            llGetOwner() );
    } else {
        return FALSE;
    }
    return TRUE;
}

linkMessage( integer prim, list msg )
{
    llMessageLinked( prim, SCAN_MASK, llDumpList2String( msg, LINK_MSG_DELIM ),
        llGetOwner() );
}

targetLock( key ping )
{
    // linkMessage( LINK_SET, [ "trgt", ping ] );
    llRegionSay( userChannel, (string)llGetOwner() 
        + "|a!tgt|" + (string)ping );
}

set_lit( integer prim, integer on )
{
    if ( prim > 1 ) {
           if ( on ) {
            llSetLinkColor( prim, 
                llList2Vector( 
                    llGetLinkPrimitiveParams( LINK_ROOT, 
                        [ PRIM_COLOR, LIT_FACE ] )
                    , 0 ), 
                ALL_SIDES );
        } else {
            llSetLinkColor( prim, 
                llList2Vector( 
                    llGetLinkPrimitiveParams( LINK_ROOT, 
                        [ PRIM_COLOR, DIM_FACE ] )
                    , 0 ), 
                ALL_SIDES );
        }
    }
}

key get_target()
{
    return (key)llList2String( 
        llGetLinkPrimitiveParams( targetPrim, [ PRIM_DESC ] )
        , 0 );
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

integer key2channel( key id )
{
    return -1 * (integer)( "0x" + llGetSubString(id, -12, -5));
}

// -------------------------------------------------------------------------
// Configuration items
string notecard = "*Configuration";     // Notecard with configuration
key queryID;                            // Current query
integer noteLine;                       // Notecard line

// ===========================================================================
// Sensors off
// ===========================================================================
default
{
    state_entry()
    {
        owner = llGetOwner();
        list prims = get_link_numbers( [ "sensors", "scan:mode:bio",
            "scan:mode:energy", "scan:mode:mass", "scan:mode:scripts", 
            "sense:future", "scan:filter", "menu",
            "target" ] );
        status = llList2Integer( prims, 0 );
        bioPrim = llList2Integer( prims, 1 );
        energyPrim = llList2Integer( prims, 2 );
        massPrim = llList2Integer( prims, 3 );
        scriptPrim = llList2Integer( prims, 4 );
        landPrim = llList2Integer( prims, 5 );
        filterPrim = llList2Integer( prims, 6 );
        menuPrim = llList2Integer( prims, 7 );
        targetPrim = llList2Integer( prims, 8 );
        set_lit( filterPrim, FALSE );
        report_mode();
        userChannel = key2channel( owner );
        
        if ( llGetAttached() ) {
            llRequestPermissions( owner, PERMISSION_TRACK_CAMERA );
        }
    }
    
    attach( key id )
    {
        if ( id ) {
            llRequestPermissions( owner, PERMISSION_TRACK_CAMERA );
        }
    }
    
    run_time_permissions( integer perm )
    {
        if ( perm & PERMISSION_TRACK_CAMERA ) {
            state standby;
        }
    }
    
    state_exit()
    {
        //llWhisper( DEBUG_CHANNEL, llGetScriptName() + " initialized; " 
        //    + (string)llGetFreeMemory() + " bytes free.");
    }
}

state standby
{
    state_entry()
    {
        linkMessage( status, [ "display off" ] );
        linkMessage( status, [ "clear screen" ] );
        linkMessage( status, [ "unstatus", "Scan Mode:" ] );
        set_lit( bioPrim, FALSE );
        set_lit( energyPrim, FALSE );
        set_lit( massPrim, FALSE );
        set_lit( scriptPrim, FALSE );
        set_lit( landPrim, FALSE );
        mode = FALSE;
    }
    
    on_rez( integer p )
    {
        llResetScript();
    }
    
    link_message( integer source, integer flag, string message, key id )
    {
        if ( flag & SCAN_MASK ) {
            list msg = llParseString2List( message,DELIMIT,[]);
            string cmd = llList2String(msg, 0);
            
            //llOwnerSay( "[" + (string)this + ":" + (string)flag + ":" + llKey2Name(id) + ":default]" + message );
            if ( cmd == "scan" )
            {
                scan_commands( msg );
                if ( active ) {
                    state scanning;
                }
            }
            else if ( cmd == "diag" ) {
                llWhisper( 0, "/me SCANNER" +
                    "\nOff" + 
                    "\n" + (string)llGetFreeMemory() + " bytes free."
                    );
            }
            else if ( cmd == "reset" ) {
                llResetScript();
            }
        }
    }
}

// ===========================================================================
// Sensors scanning & track-while-scan
// ===========================================================================
state scanning
{
    state_entry()
    {
        active = TRUE;
        integer i;
        if ( mode == FALSE ) mode = AGENT;
        sensorStart();
    }
    
    timer()
    {
        scan();
    }
    
    on_rez( integer param )
    {
        llResetScript();
    }
    
    sensor( integer scanned ) // scanned is the number of detected targets
    {
        llSetTimerEvent( 0.0 );
        list detected;
        integer i;
        integer c;
        do {
            detected += [  llDetectedKey( i ) ];
            ++c;
            ++i;
        } while ( i < scanned );
        linkMessage( LINK_THIS, [ "detected", c ] + detected );
        llSetTimerEvent( PRF );
    }
        
    listen ( integer channel, string sender, key id, string message )
    {
        // Phoenix contacts
        list contacts = llParseString2List( message, [ "," ], [] );
        contacts = llList2List( contacts, 2, -1 );
        integer scanned = llGetListLength( contacts );
        linkMessage( status, [ "detected", scanned ] + contacts );
        if ( id == llGetOwner() ) {
            if ( ( channel == PHOENIX ) && firestormHandle ) {
                llListenRemove( firestormHandle );
                firestormHandle = FALSE;
            } else if ( ( channel == FIRESTORM ) && phoenixHandle ) {
                llListenRemove( phoenixHandle );
                phoenixHandle = FALSE;
            }
        }
        // llSetTimerEvent( 0.0 );
    }
     
    changed( integer change )
    {
        if ( change & CHANGED_REGION ) {
            if ( phoenixHandle || firestormHandle ) {
                llTriggerSound( PHOENIX_UPDATE, 1.0 );
            }
        }
    }    
    state_exit()
    {
        llSetTimerEvent( 0.0 );
        linkMessage( LINK_ALL_OTHERS, [ "clear screen" ] );
    }

    link_message( integer source, integer flag, string message, key id )
    {
        if ( flag & SCAN_MASK ) {
            list msg = llParseString2List( message, DELIMIT, [] );
            string cmd = llList2String( msg, 0 );
            
            // llOwnerSay( llGetScriptName() + ":" + message );        
    
            if ( cmd == "scan" )
            {
                scan_commands( msg );
                if ( !active ) {
                    state standby;
                }
            } else if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "diag" ) {
                llWhisper( 0, "/me SCANNER" +
                    "\nScanning, mode " + (string)mode + 
                    "\n" + (string)llGetFreeMemory() + " bytes free."
                    );
            } else if ( cmd == "region" ) {
                if ( phoenixHandle ) {
                    llTriggerSound( PHOENIX_UPDATE, 1.0 );
                }
            }
        }
    }
}
// Copyright ©2011
// All rights reserved