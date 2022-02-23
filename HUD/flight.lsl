// ===========================================================================
// Flight Assist                                                             \
// By Jack Abraham                                                        \__
// ===========================================================================

float mass;                     // current mass
integer moveLock = FALSE;       // Whether to movelock or not
integer motor = FALSE;          // Indicates whether momentum assistance is on
integer agentInfo;              // A bitmask of the agent/avi current state
integer requestedKeys;          // A bitmask of the control keys
integer requestedPerms;         // A bitmask of the required permissions
key wearer;                     // UUID of the wearer 
integer this;                   // link message id
integer min_boost = 0;          // minimum boost level
integer off = FALSE;            // Boost disabled

integer hardLock = TRUE;        // Slam on brakes when move lock enabled

float fastTimer = 0.1;          // Timer intervals
float slowTimer = 1.0;

float topSpeed = 0.0;           // Top speed so far acheived.

integer cruise = FALSE;         // Cruise control flag

integer FLY_NORMAL = 1;         // Exit flags to trigger state changes
integer FLY_PURSUIT = 2;
integer FLY_CAMERA = 3;

// =========================================================================
// Followers & flycam

float FLIGHT_SPEED = 15.0;      // Faux flight speed limit
float RUN_SPEED = 7.5;
float WALK_SPEED = 4.0;         // Faux walking speed

integer movetoTarget;           // Movement target handle
float MOVETO_ERROR = 3.0;       // Close enough to stop

vector CAMERA_OFFSET = <3.0, 0.0, 0.0>;
vector camPos;

integer MAX_JUMP = 63;

move_to( vector to, float error ) {
    vector from = get_pos( llGetOwner() );
    float distance;
    float flightTime;
    vector startRegion;
    vector region;
    vector waypoint;
    integer j;
    vector e;
    float speed;
    integer agentInfo = llGetAgentInfo( llGetOwner() );
    if ( agentInfo & AGENT_FLYING ) {
        speed = FLIGHT_SPEED;
    } else if ( agentInfo & AGENT_ALWAYS_RUN ) {
        speed = RUN_SPEED;
    } else {
        speed = WALK_SPEED;
    }
    
    if ( !offworld( from, to ) ) {
        startRegion = llGetRegionCorner() / 256.;
        llTargetRemove( movetoTarget );
        llTarget( to, error );
        region = llGetRegionCorner() / 256.;
        if ( region != startRegion ) {
        }
        
        distance = llVecDist( from, to );
        if ( distance > MAX_JUMP ) {
            to = from + ( llVecNorm( to - from ) * MAX_JUMP );
            vector current = llGetVel();
            llSetForce( llVecNorm( to - from ) * CRUISE_THRUST.x * llGetMass(),
                FALSE );
            checkBuoyancy( from );
        } else {
            llMoveToTarget( to, distance / speed );
            llSetForce( ZERO_VECTOR, TRUE );
        }
    }
}

integer offworld( vector here, vector there )
{
    if ( there.x < 0. || there.x >= 256. || there.y < 0. || there.y >= 256. ) {
        return llEdgeOfWorld( here, there-here );
    }
    return FALSE;
}

vector get_pos( key id )
{
    list params = llGetObjectDetails( id, [ OBJECT_POS, OBJECT_VELOCITY ] );
    return llList2Vector( params, 0 ) + ( llList2Vector( params, 1 ) * 0.25 );
}

key followMe = NULL_KEY;
float followRange = 5.0;
float SCAN_RANGE = 96.0;
float FOLLOW_ERROR = 5.0;

follow()
{
    if ( llKey2Name( followMe ) == "" ) return;
    vector me = get_pos( llGetOwner() );
    vector him = get_pos( followMe );
    if ( llVecDist( me, him ) > followRange ) {
        move_to( him, FOLLOW_ERROR );
    } else {
        llTargetRemove( movetoTarget );
        llStopMoveToTarget();
        movetoTarget = FALSE;
    }
}

key get_target()
{
    return (key)llList2String( 
        llGetLinkPrimitiveParams( targetPrim, [ PRIM_DESC ] )
        , 0 );
}

face( vector tpos )
{
    vector opos = llList2Vector(
        llGetObjectDetails( llGetOwner(), [ OBJECT_POS ] ), 0);
    float angle = llAtan2( tpos.x - opos.x, tpos.y - opos.y );
    llMessageLinked( LINK_ROOT, RLV_MASK, llDumpList2String(
        [ "rlvr", "@setrot:" + (string)angle + "=force" ], LINK_DELIM ),
        llGetOwner() );
}

// =========================================================================

vector getForwardDir( integer mouselook )
{
    vector ret;

    ret = <1,0,0>*llGetCameraRot(); // camera rotation leads forward direction
    if ( !mouselook ) {
        ret.z = 0;
    }

    return llVecNorm(ret);
}

getPermissions()
{
    if ((llGetPermissions() & requestedPerms) == requestedPerms)
    {
        llTakeControls(requestedKeys, TRUE, TRUE);
    }
    else
    {
        llRequestPermissions(wearer, requestedPerms);
    }
}

gotControlInput(integer held)
{
    agentInfo = llGetAgentInfo(wearer);

    if ( moveLock && held ) {
        llStopMoveToTarget();
    }

    if (!(held & requestedKeys) && !cruise)
    {
        if (agentInfo & AGENT_FLYING)
        {
            state hover;
        }
    }
    
    if (agentInfo & AGENT_FLYING)
    {
        if (held & requestedKeys)
        {
            vector p = llGetPos();
            vector dir;
            float assist = 0.0;
            vector forward = getForwardDir( agentInfo & AGENT_MOUSELOOK );
    
            if (p.z > llGround(ZERO_VECTOR)+50.0)
            {
                llSetBuoyancy(1.0);
                if ( ( held & CONTROL_UP ) || ( forward.z > 0 )) {
                    dir += <0., 0., 1.0>;
                }
                //if ( assist == 0.0 )
                //    assist = 1.0;
            }
            else
            {
                // For some reason, if you are below
                // llGround()+50.0 meters, you will
                // slowly rise to that height if you
                // llSetBuoyancy(1.0). An avatar can maintain
                // hover below this height w/o assist; so
                // no buoyancy change.
                llSetBuoyancy(0.0);
            }
            
            // dir = assist * mass * dir;
            dir = dir * mass;
    
            llApplyImpulse( dir, FALSE);
    
            motor = TRUE;
            
            set_timer( fastTimer );
        }
    }
}

start_pursuit()
{
    if ( !movetoTarget && 
        llVecDist( get_pos( followMe ), llGetPos() ) > followRange ) 
    {
        face( get_pos( followMe ) );
        follow();
    }
    integer scanMode = ACTIVE|PASSIVE;
    if ( llGetAgentSize( followMe ) ) scanMode = AGENT;
    llSensorRepeat( "", followMe, scanMode, SCAN_RANGE, PI, 0.25 );
    llMessageLinked( LINK_ROOT, COMM_MASK, 
        llDumpList2String( [ "unstatus", "Autopilot" ],
        LINK_DELIM ), llGetOwner() );
    llMessageLinked( LINK_ROOT, COMM_MASK, 
        llDumpList2String( [ "status",
            "Autopilot: Pursuing " + llKey2Name( followMe ) ],
        LINK_DELIM ), llGetOwner() );
}

vector CRUISE_THRUST = <69.0, 0.0, 0.0>;

checkBuoyancy( vector p )
{
    if (p.z > llGround(ZERO_VECTOR)+50.0)
    {
        llSetBuoyancy(1.0);
    }
    else
    {
        // For some reason, if you are below
        // llGround()+50.0 meters, you will
        // slowly rise to that height if you
        // llSetBuoyancy(1.0). An avatar can maintain
        // hover below this height w/o assist; so
        // no buoyancy change.
        llSetBuoyancy(0.0);
    }
}

do_cruise()
{
    if ( cruise ) {
        vector current = llGetVel() / llGetRot();
        llSetForce( <CRUISE_THRUST.x - current.x, 
            CRUISE_THRUST.y - current.y, 0. - current.z > * llGetMass(),
            TRUE );
        checkBuoyancy( llGetPos() );
        set_timer( fastTimer );
    }
}

set_cruise( integer flag )
{
    cruise = flag;
    if ( !cruise ) {
        llSetForce( ZERO_VECTOR, TRUE );
    }
    set_lit( cruisePrim, cruise );
}

set_moveLock( integer on )
{
    moveLock = on;
    set_lit( anchorPrim, moveLock );
}

float old_timer;

set_timer( float time )
{
    if ( time != old_timer ) {
        llSetTimerEvent( time );
        old_timer = time;
    }
}

onAttach(key avatar)
{
    wearer = avatar;
    if (wearer != NULL_KEY)
    {
        getPermissions();
    }
}

// --------------------------------------------------------------------------
// Communications
integer NAV_MASK            = 0x40000000;
integer COMM_MASK           = 0x10000000;
integer RLV_MASK            = 0x20000000;

// Interpret link messages
integer handle_command( integer source, integer flag, string message, key id )
{
    if ( flag & NAV_MASK ) {
        list parsed = llParseString2List( message, [ LINK_DELIM ], [] );
        string cmd = llList2String( parsed, 0 );
        
        if ( cmd == "trvl" ) {
            cmd = llList2String( parsed, 1 );
            
            // llOwnerSay( llGetScriptName() + ": " + cmd );
            
            if ( cmd == "anchor" ) {
                set_moveLock( !moveLock );
            } else if ( cmd == "cruise" ) {
                set_cruise( !cruise );
            } else if ( cmd == "tocam" ) {
                return FLY_CAMERA;
            } else if ( cmd == "follow" ) {
                return FLY_PURSUIT;
            } else if ( cmd == "menu" ) {
                flight_menu();
            } else if ( cmd == "hard stop" ) {
                hardLock = !hardLock;
                if ( hardLock ) {
                    llOwnerSay( "Hard move lock." );
                } else {
                    llOwnerSay( "Soft move lock." );
                }
            } else if ( cmd == "rset" ) {
                llResetScript();
            }
        } else if ( cmd == "rset" ) {
            llResetScript();
        } else if ( cmd == "fmem" ) {
            llMessageLinked( source, llGetFreeMemory(), "fmem", id );
        }

    }
    return FALSE;
}

flight_menu()
{
    llOwnerSay( llGetScriptName() + " Flight menu " + llGetLinkName( menuPrim ) );
    list items;
    if ( cruise ) items += [ "Cruise Off" ];
    else items += [ "Cruise On" ];
    if ( moveLock ) items += [ "Move Lock Off" ];
    else items += [ "Move Lock On" ];
    if ( hardLock ) items += [ "Soft Stop" ];
    else items += [ "Hard Stop" ];
    
    list cmds = ["trvl§cruise", "trvl§anchor", "trvl§hard stop" ];
    llMessageLinked( menuPrim, NAV_MASK,
        llDumpList2String( [ "menu",
            "Flight Control",
            llList2CSV( items ),
            llList2CSV( cmds ) ],
            LINK_DELIM ),
        llGetOwner() );
}

string LINK_DELIM = "§";
// Send a formatted link message
linkMessage( integer target, integer flags, list msg )
{
    if ( target > 999 )
        target = target / 1000;
    llMessageLinked( target, flags, 
            llDumpList2String( msg, LINK_DELIM ), wearer );
}
            
integer LIT_SIDE = 0;
integer DIM_SIDE = 2;
integer cruisePrim;
integer anchorPrim;
integer menuPrim;
integer flycamPrim;
integer pursuitPrim;
integer targetPrim;
integer statusPrim = LINK_ROOT;
   
set_lit( integer prim, integer on )
{
    if ( prim < 2 ) return;
    if ( on ) {
        llSetLinkColor( prim, llGetColor( LIT_SIDE ), ALL_SIDES );
    } else {
        llSetLinkColor( prim, llGetColor( DIM_SIDE ), ALL_SIDES );
    }
}

list get_link_numbers ( list names )
{
    integer c = llGetNumberOfPrims();
    integer i = -1;
    do {
        i = llListFindList( names, [ llGetLinkName( c ) ] );
        if ( i > -1 ) {
            names = llListReplaceList( names, [c], i, i );
        }
    } while ( c-- >= 0 );
    return names;
}

// ===========================================================================

default
{
    state_entry()
    {
        requestedKeys = CONTROL_FWD | CONTROL_UP | CONTROL_DOWN | CONTROL_BACK;
        requestedPerms = PERMISSION_TRACK_CAMERA | PERMISSION_TAKE_CONTROLS;
        
        mass = llGetMass();
        
        list prims = get_link_numbers( [ "trvl:cruise", "trvl:anchor", "menu",
            "trvl:tocam", "trvl:follow", "target" ] );
        cruisePrim = llList2Integer( prims, 0 );
        anchorPrim = llList2Integer( prims, 1 );
        menuPrim = llList2Integer( prims, 2 );
        flycamPrim = llList2Integer( prims, 3 );
        pursuitPrim = llList2Integer( prims, 4 );
        targetPrim = llList2Integer( prims, 5 );
        set_lit( cruisePrim, cruise );
        set_lit( anchorPrim, moveLock );
        set_lit( flycamPrim, FALSE );
        set_lit( pursuitPrim, FALSE );
        
        // Check if HUD is already attached
        wearer = llGetOwner(); // for now
        if (llGetAttached() != 0)
        {
            getPermissions();
        }
        llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String( [ 
            "unstatus", "Autopilot" ],
            LINK_DELIM ), llGetOwner() );
        
        llSetTimerEvent( 0.1 );
    }

    on_rez(integer param)
    {
        // llResetScript();
    }

    attach(key agent)
    {
        onAttach(agent);
    }

    run_time_permissions(integer perm)
    {
        if (perm & PERMISSION_TAKE_CONTROLS)
        {
            llTakeControls(requestedKeys, TRUE, TRUE);
        }
    }
    
    link_message( integer source, integer flag, string message, key id )
    {
        integer mode = handle_command( source, flag, message, id );
        if ( mode ) {
            if ( mode == FLY_CAMERA ) {
                state flycam;
            } else if ( mode == FLY_PURSUIT ) {
                state pursuit;
            }
        }
    }
    
    control(key owner, integer held, integer change)
    {
        gotControlInput(held);
        
        if ( cruise && change & CONTROL_BACK ) {
            set_cruise( FALSE );
        }
    }
    
    timer()
    {
        agentInfo = llGetAgentInfo( wearer );
        if ( !(agentInfo & AGENT_FLYING ))
        {
            state landed;
        }
        do_cruise();
    }

    state_exit()
    {
        llSetTimerEvent( 0. );
    }
}

// ===========================================================================

state hover
{
    state_entry()
    {
        motor = FALSE;
        vector pos = llGetPos();
        if ( moveLock )
        {
            if ( hardLock ) {
                llMoveToTarget( pos, 0.05 );
            } else {
                llMoveToTarget( pos + ( llGetVel() * 0.2 ), 0.2);
            }
            llSetVehicleType( VEHICLE_TYPE_AIRPLANE );
            llSetVehicleVectorParam( VEHICLE_LINEAR_FRICTION_TIMESCALE,
                <0.05, 0.05, 0.05> );
        }
        checkBuoyancy( pos );
        llTakeControls(requestedKeys, TRUE, TRUE);
        
        set_cruise( FALSE );
        set_timer( slowTimer );
    }

    changed(integer what)
    {
        if (what & CHANGED_REGION)
        {
            state landed;
        }
    }

    on_rez(integer param)
    {
        // llResetScript();
    }

    control(key owner, integer held, integer change)
    {
        gotControlInput(held);

        state default;
    }

    link_message( integer source, integer flag, string message, key id )
    {
        integer mode = handle_command( source, flag, message, id );
        if ( mode ) {
            if ( mode == FLY_CAMERA ) {
                state flycam;
            } else if ( mode == FLY_PURSUIT ) {
                state pursuit;
            }
        }
    }

    state_exit()
    {
        llStopMoveToTarget();
        movetoTarget = FALSE;
        llSetVehicleType( VEHICLE_TYPE_NONE );
        llSetTimerEvent( 0. );
    }
}


// ===========================================================================

state landed
{
    state_entry()
    {
        llStopMoveToTarget(); // just in case
        movetoTarget = FALSE;
        llSetBuoyancy(0.0);
        llSetTimerEvent( slowTimer );
        set_cruise( FALSE );
        // set_moveLock( FALSE );
    }

    on_rez(integer param)
    {
        // llResetScript();
    }

    attach(key agent)
    {
        onAttach(agent);
    }

    run_time_permissions(integer perm)
    {
        if (perm & PERMISSION_TAKE_CONTROLS)
        {
            llTakeControls(requestedKeys, TRUE, TRUE);
        }
    }

    link_message( integer source, integer flag, string message, key id )
    {
        integer mode = handle_command( source, flag, message, id );
        if ( mode ) {
            if ( mode == FLY_CAMERA ) {
                state flycam;
            } else if ( mode == FLY_PURSUIT ) {
                state pursuit;
            }
        }
    }


    timer()
    {
        agentInfo = llGetAgentInfo(wearer);

        if (agentInfo & AGENT_FLYING)
        {
            state default;
        }
    }
}

// ===========================================================================

state disabled
{
    state_entry()
    {
        llSetBuoyancy(0.0);
        llStopMoveToTarget(); // just in case
        movetoTarget = FALSE;
        llSetVehicleType( VEHICLE_TYPE_NONE );
        set_cruise( FALSE );
    }

    attach(key agent)
    {
        onAttach(agent);
    }

    run_time_permissions(integer perm)
    {
        if (perm & PERMISSION_TAKE_CONTROLS)
        {
            llTakeControls(requestedKeys, TRUE, TRUE);
        }
    }

    on_rez(integer param)
    {
        // llResetScript();
    }

    link_message( integer source, integer flag, string message, key id )
    {
        integer mode = handle_command( source, flag, message, id );
        if ( mode ) {
            if ( mode == FLY_CAMERA ) {
                state flycam;
            } else if ( mode == FLY_PURSUIT ) {
                state pursuit;
            }
        }
    }
}
        
// ===========================================================================

state flycam
{
    state_entry()
    {
        llSetTimerEvent( 0. );
        motor = FALSE;

        llTakeControls(requestedKeys | CONTROL_ROT_LEFT | CONTROL_ROT_RIGHT, 
            TRUE, TRUE);
        
        set_moveLock( FALSE );
        set_cruise( FALSE );
        set_lit( flycamPrim, TRUE );
        camPos = llGetCameraPos() + 
            ( CAMERA_OFFSET * llGetCameraRot() );
        llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String( [ "status",
            "Autopilot: Any movement key begins,\nback aborts" ],
            LINK_DELIM ), llGetOwner() );
        llSetTimerEvent( 25.0 );
    }
        
    on_rez(integer param)
    {
        llResetScript();
    }
    
    control( key id, integer held, integer change )
    {
        if ( held & CONTROL_BACK ) {
            state default;
        } else {
            llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String( [ 
                "unstatus", "Autopilot" ],
                LINK_DELIM ), llGetOwner() );
            llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String( [ "status",
                "Autopilot: Engaged" ],
                LINK_DELIM ), llGetOwner() );
            face( camPos );
            move_to( camPos, MOVETO_ERROR );
        }
    }

    at_target(integer number, vector curPos, vector targPos)
    {
        llTargetRemove( movetoTarget );
        movetoTarget = FALSE;
        state hover;
    }
    
    not_at_target()
    {
        move_to( camPos, MOVETO_ERROR );
    }

    link_message( integer source, integer flag, string message, key id )
    {
        integer mode = handle_command( source, flag, message, id );
        if ( mode ) {
            if ( mode == FLY_CAMERA ) {
                state default;
            } else if ( mode == FLY_PURSUIT ) {
                state pursuit;
            }
        }
    }
    
    timer()
    {
        state hover;
    }

    state_exit()
    {
        set_lit( flycamPrim, FALSE );
        if ( movetoTarget ) {
            llTargetRemove( movetoTarget );
        }
        llStopMoveToTarget();
        movetoTarget = FALSE;
        llSensorRemove();
        llSetTimerEvent( 0. );
        llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String( [ 
            "unstatus", "Autopilot" ],
            LINK_DELIM ), llGetOwner() );
    }
}

// ===========================================================================
// Pursue target

state pursuit
{
    state_entry()
    {
        if ( followMe == NULL_KEY ) {
            followMe = get_target();
        }
        if ( followMe == NULL_KEY ) {
            state default;
        }
        motor = FALSE;
        
        llTakeControls(requestedKeys | CONTROL_ROT_LEFT | CONTROL_ROT_RIGHT, 
            TRUE, TRUE);
        
        set_moveLock( FALSE );
        set_cruise( FALSE );
        llMessageLinked( LINK_ROOT, COMM_MASK,
            llDumpList2String( [ "IM", "Pursuing " + llKey2Name( followMe ) ],
                LINK_DELIM ),
            llGetOwner() );
        set_lit( pursuitPrim, TRUE );
        if ( llGetAgentInfo(wearer) & ( AGENT_FLYING | AGENT_IN_AIR ) ) {
            llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String( [ "status",
                "Autopilot: Any movement key begins,\nback aborts" ],
                LINK_DELIM ), llGetOwner() );
            llSetTimerEvent( 1.0 );
        } else {
            llSetTimerEvent( 0. );
            start_pursuit();
        }
    }
        
    on_rez(integer param)
    {
        llResetScript();
    }

    control(key owner, integer held, integer change)
    {
        if ( held & CONTROL_BACK ) {
            state default;
        } else {
            start_pursuit();
            llSetTimerEvent( 0. );
        }
    }

    link_message( integer source, integer flag, string message, key id )
    {
        integer mode = handle_command( source, flag, message, id );
        if ( mode ) {
            if ( mode == FLY_CAMERA ) {
                state flycam;
            } else if ( mode == FLY_PURSUIT ) {
                state default;
            }
        }
    }

    at_target(integer number, vector curPos, vector targPos)
    {
        llStopMoveToTarget();
        llTargetRemove( movetoTarget );
        movetoTarget = FALSE;
    }

    sensor( integer d )
    {
        if ( followMe != get_target() ) {
            followMe = get_target();
            if ( followMe ) {
                face( get_pos( followMe ) );
                follow();
                integer scanMode = ACTIVE|PASSIVE;
                if ( llGetAgentSize( followMe ) ) scanMode = AGENT;
                llSensorRepeat( "", followMe, scanMode, SCAN_RANGE, PI, 0.25 );
                llMessageLinked( LINK_ROOT, COMM_MASK,
                    llDumpList2String( [ "IM", "Pursuing " 
                            + llKey2Name( followMe ) ],
                        LINK_DELIM ),
                    llGetOwner() );
                llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String( [ 
                    "unstatus", "Autopilot" ],
                    LINK_DELIM ), llGetOwner() );
                llMessageLinked( LINK_ROOT, COMM_MASK, 
                    llDumpList2String( [ "status",
                    "Autopilot: Pursuing " + llKey2Name( followMe ) ],
                    LINK_DELIM ), llGetOwner() );
                } else {
                    state default;
                }

        }
        if ( llVecDist( llDetectedPos( 0 ), llGetPos() ) > FOLLOW_ERROR ) {
            if ( followMe ) {
                face ( get_pos( followMe ) );
                follow();
            }
        }
    }
    
    no_sensor()
    {
        if ( followMe == get_target() ) {
            llMessageLinked( LINK_ROOT, COMM_MASK,
                llDumpList2String( [ "IM", "Lost target; ending pursuit" ],
                    LINK_DELIM ),
                llGetOwner() );
            state default;
        } else {
            followMe = get_target();
        }
    }
    
    timer()
    {
        llOwnerSay( "Timeout" );
        state default;
    }
    
    state_exit()
    {
        followMe = NULL_KEY;
        llStopMoveToTarget();
        movetoTarget = FALSE;
        llSensorRemove();
        llSetTimerEvent( 0. );
        llMessageLinked( LINK_ROOT, COMM_MASK, llDumpList2String( [ 
            "unstatus", "Autopilot" ],
            LINK_DELIM ), llGetOwner() );
    }
}

