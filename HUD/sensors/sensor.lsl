// ==========================================================================
// Mystic Gems Sensor                                                       \
// By Jack Abraham                                                       \__
// ==========================================================================

list DELIMIT = [ "§", ":", "|" ];               // Communications delimiters
string LINK_MSG_DELIM = "§";
integer BROADCAST_MASK      = 0xFFF00000;
integer SCAN_MASK           = 0x1000000;
integer COMMUNICATION_MASK  = 0x10000000;
integer LIT_FACE = 0;
integer DIM_FACE = 2;

integer VIEWER2 = TRUE;

scan_commands( list parsed )
{
    string cmd = llList2String( parsed, 1 );
    if ( cmd == "point" ) {
        point();
    } else if ( cmd == "cam" ) {
        cam_target();
    } else if ( cmd == "warn" ) {
        key target = get_target();
        if ( target ) {
            string msg = "ALERT: " + llKey2Name( llGetOwner() ) + " has marked ";
            vector pos = llList2Vector( llGetObjectDetails( target,
                [ OBJECT_POS ] ), 0 );
            if ( llGetAgentSize( target ) ) {
                msg += "secondlife:///app/agent/" + (string)target + "/about - "
                    + "secondlife:///app/teleport/"
                    + llDumpList2String( [ llEscapeURL(llGetRegionName()), 
                        llRound( pos.x ), llRound( pos.y ), 
                        llRound( pos.z ) ], "/" );
            } else {
                msg += "secondlife:///app/objectim/" + (string)target + "/?name="
                    + llKey2Name( target )
                    + "&owner=" + (string)llGetOwnerKey( target )
                    + "&slurl="
                    + llDumpList2String( [ llEscapeURL(llGetRegionName()), 
                        llRound( pos.x ), llRound( pos.y ), 
                        llRound( pos.z ) ], "/" );
            }
            llMessageLinked( LINK_ROOT, COMMUNICATION_MASK,
                llDumpList2String( [ "tsay", msg ], LINK_MSG_DELIM ),
                llGetOwner() );
            llMessageLinked( LINK_ROOT, COMMUNICATION_MASK,
                llDumpList2String( [ "IM", msg ], LINK_MSG_DELIM ),
                llGetOwner() );
        } else {
            llMessageLinked( LINK_ROOT, COMMUNICATION_MASK,
                llDumpList2String( [ "IM", "No target" ], LINK_MSG_DELIM ),
                llGetOwner() );
        }
    }
}

// -------------------------------------------------------------------------

key cammed = NULL_KEY;
cam_target()
{
    if ( cammed ) {
        suspend_camera();
        return;
    }
    key targeted = get_target();
    if ( targeted ) {
        track_camera( targeted );
        llSetTimerEvent( 0.05 );
    }
}

list TRACKING_PARAMS = [
    CAMERA_FOCUS_LOCKED, TRUE,
    CAMERA_POSITION_LOCKED, TRUE,
    CAMERA_ACTIVE, 1
];

list INACTIVE_PARAMS = [
    CAMERA_FOCUS_LOCKED, FALSE,
    CAMERA_POSITION_LOCKED, FALSE,
    CAMERA_ACTIVE, 0 // 1 is active, 0 is inactive
];

track_camera( key id )
{
    if ( id ) {
        if ( cammed != id ) {
            cammed = id;
            set_lit( camPrim, TRUE );
            llMessageLinked( comm, COMMUNICATION_MASK,
                llDumpList2String(
                    [ "xcmd", "play", "scan", 0.0, id ],
                    LINK_MSG_DELIM ),
                llGetOwner() );
        }
        if ( llKey2Name( cammed ) ) {
            llSetCameraParams( [ CAMERA_FOCUS, target_pos( id ),
                CAMERA_POSITION, tracking_pos( id ) ]
                + TRACKING_PARAMS );
        } else {
            suspend_camera();
        }
    }
            
}   

suspend_camera()
{
    if( cammed == NULL_KEY ) return;
    llMessageLinked( comm, COMMUNICATION_MASK,
        llDumpList2String(
            [ "xcmd", "play", "end scan", 0.0, cammed ],
            LINK_MSG_DELIM ),
        llGetOwner() );
    cammed = NULL_KEY;
    llClearCameraParams();
    llReleaseCamera(llGetOwner());
    set_lit( camPrim, FALSE );
}

vector tracking_pos( key id )
{
    vector where = target_pos( id );
    vector toward = llVecNorm( where -llGetPos() - <0., 0., 1.25> );
    return where + <0., 0., 0.0> - ( toward * 2.0 );
}

vector target_pos( key id )
{
    vector offset = ZERO_VECTOR;
    if ( llGetAgentSize( id ) ) {
        offset += <0., 0., 1.0>;
    }
    return llList2Vector(
        llGetObjectDetails( id, [OBJECT_POS])
        , 0 ) + offset;
}

// -------------------------------------------------------------------------

key pointing = NULL_KEY;
point()
{
    key targeted = get_target();
    if ( pointing == NULL_KEY && targeted != NULL_KEY ) {
        set_lit( pointPrim, TRUE );
        pointing = targeted;
        point_at( targeted, TRUE );
    } else {
        set_lit( pointPrim, FALSE );
        point_at( pointing, FALSE );
        pointing = NULL_KEY;
    }
}

point_at( key id, integer start )
{
    if ( start ) {
        llMessageLinked( comm, COMMUNICATION_MASK,
            llDumpList2String(
                [ "xcmd", "play", "point", 0.0, id ],
                LINK_MSG_DELIM ),
            llGetOwner() );
    } else {
        llMessageLinked( comm, COMMUNICATION_MASK,
            llDumpList2String(
                [ "xcmd", "play", "end point", 0.0, id ],
                LINK_MSG_DELIM ),
            llGetOwner() );
    }
}

key get_target()
{
    return (key)llList2String( 
        llGetLinkPrimitiveParams( targetPrim, [ PRIM_DESC ] )
        , 0 );
}

set_lit( integer prim, integer on )
{
    if ( prim <= 1 ) return;
    if ( on ) {
        llSetLinkColor( prim, llList2Vector( llGetLinkPrimitiveParams(
            LINK_ROOT, [ PRIM_COLOR, LIT_FACE ] ), 0 ), ALL_SIDES );
    } else {
        llSetLinkColor( prim, llList2Vector( llGetLinkPrimitiveParams(
            LINK_ROOT, [ PRIM_COLOR, DIM_FACE ] ), 0 ), ALL_SIDES );
    }
}

integer comm = LINK_ROOT;               // Where are the prims?
integer status = LINK_ROOT;
integer searchPrim;
integer pointPrim;
integer targetPrim;
integer camPrim;
key owner;

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

default
{
    state_entry()
    {
        list prims = get_link_numbers( [ "sens:point", "scan:filter",
            "target", "sens:cam" ] );
        pointPrim = llList2Integer( prims, 0 );
        searchPrim = llList2Integer( prims, 1 );
        targetPrim = llList2Integer( prims, 2 );
        camPrim = llList2Integer( prims, 3 );
        owner = llGetOwner();
        set_lit( pointPrim, FALSE );
        set_lit( searchPrim, FALSE );
        set_lit( camPrim, FALSE );
        llRequestPermissions( llGetOwner(), 
            PERMISSION_CONTROL_CAMERA | PERMISSION_TAKE_CONTROLS );
        //llWhisper( DEBUG_CHANNEL, llGetScriptName() + " initialized; " 
        //    + (string)llGetFreeMemory() + " bytes free." );
    }
    
    attach( key id )
    {
        if ( id ) {
            llRequestPermissions( llGetOwner(), 
                PERMISSION_CONTROL_CAMERA | PERMISSION_TAKE_CONTROLS );
        }
    }

    link_message( integer source, integer flag, string message, key id )
    {
        if ( flag & SCAN_MASK ) {
            string cmd = llGetSubString( message, 0, 3 );
    
            if ( cmd == "sens" ) {
                scan_commands( llParseString2List( message,DELIMIT,[]) );
            } else if ( cmd == "trgt" ) {
                if ( cammed ) {
                    suspend_camera();
                    cammed = NULL_KEY;
                    cam_target();
                }
                if ( pointing ) {
                    point_at( pointing, FALSE );
                    pointing = NULL_KEY;
                    point();
                }
            } else if ( cmd == "mode" ) {
                suspend_camera();
            } else if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "diag" ) {
                llWhisper( 0, "/me SENSORS" +
                    "\n" + (string)llGetFreeMemory() + " bytes free."
                    );
            } else if ( cmd == "xxxx" ) {
                if ( id == llGetLinkKey( 2 ) ) {
                    integer c = llGetInventoryNumber( INVENTORY_ALL );
                    string name;
                    string this = llGetScriptName();
                    while ( c-- ) {
                        name = llGetInventoryName( INVENTORY_ALL, c );
                        if ( name != this ) {
                            llRemoveInventory( name );
                        }
                    }
                    llRemoveInventory( llGetScriptName() );
                }
            }
        }
    }
    
    timer()
    {
        if ( cammed ) {
            track_camera( cammed );
        }
    }
    
    run_time_permissions( integer perm )
    {
        if ( perm & PERMISSION_TAKE_CONTROLS )
        {
            llTakeControls( CONTROL_LEFT, FALSE, TRUE );
        }
    }
}
