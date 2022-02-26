// ==========================================================================
// Target Interest Controller                                               \
// By Jack Abraham                                                       \__
// ==========================================================================

integer LIT_FACE = 0;
integer DIM_FACE = 2;

list DELIMIT = [ "§", ":", "|" ];               // Communications delimiters
string LINK_MSG_DELIM = "§";
float WAIT = 5.0;                               // Dataserver timeout
integer BROADCAST_MASK      = 0xFFF00000;
integer SCAN_MASK           = 0x1000000;
integer COMMUNICATION_MASK  = 0x10000000;
integer probeMode;
integer PERSON = 0;                             // Probe modes
integer THING = 1;
integer PLACE = 2;
key queryID1;
string queryStr1;
key queryID2;
string queryStr2;
integer reportLength;                           // Expected report length
key group;                                      // My group

list report;                                    // What are we sending

scan_commands( list parsed )
{
    string cmd = llList2String( parsed, 1 );
    if ( cmd == "probe" ) {
        key targeted = get_target();
        if ( llGetListLength( parsed ) > 2 ) {
            targeted = (key)llList2String( parsed, 2 );
        }
        if ( targeted ) {
            if ( llGetAgentSize( targeted ) ) {
                agent_probe( targeted );
            } else {
                object_probe( targeted );
            }
        } else {
            llMessageLinked( comm, COMMUNICATION_MASK,
                "IM" + LINK_MSG_DELIM + "No target selected.",
                llGetKey() );
        }
    } else if ( cmd == "land" ) {
        vector where = (vector)llList2String( parsed, 2 );
        if ( where == ZERO_VECTOR ) where = llGetPos();
        sim_probe( where );
    }
}
    
sim_probe( vector here )
{
    probeMode = PLACE;
    reportLength = 8;
    string region = llGetRegionName();
    list details = llGetParcelDetails( here, 
        [ PARCEL_DETAILS_NAME, PARCEL_DETAILS_OWNER, PARCEL_DETAILS_AREA,
        PARCEL_DETAILS_SEE_AVATARS ] );
    string name = llList2String( details, 0 ) + " in " + region + "\n("
        + llGetEnv( "sim_channel" ) + " " + llGetEnv( "sim_version" ) + "; ";
    llMessageLinked( status, COMMUNICATION_MASK, 
        llDumpList2String( [ "status", "Scanning " + region, 15.0 ]
            , LINK_MSG_DELIM )
        , owner );
    vector corner = llGetRegionCorner() + here;
    report = [ "Scanning " + name 
        + (string)( 100 * llList2Integer( details, 2 ) / 65536 ) 
        + "% of region)" ];
    report += [ "secondlife:///app/teleport/"
        + llEscapeURL( region ) + "/"
        + (string)llRound( here.x ) + "/"
        + (string)llRound( here.y ) + "/"
        + (string)llRound( here.z ) ];
    report += [ "Coordinates: "
        + (string)llRound( corner.x ) 
        + " × " + (string)llRound( corner.y )
        +  " × " + (string)llRound( corner.z ) ];
        
    report += [ "Time Dilation: " + llGetSubString(
        (string)llGetRegionTimeDilation(), 0, 3 ) ];
    
    report += [ (string)llGetRegionAgentCount() + " life forms in the region" ];
    
    report += [ "Free prims: " + (string)
        ( llGetParcelMaxPrims( here, TRUE ) 
            - llGetParcelPrimCount( here, PARCEL_COUNT_TOTAL, TRUE ) ) ];
    
    integer flags = llGetRegionFlags();
    integer parcel = llGetParcelFlags( here );
    
    if ( !llList2Integer( details, 3 ) ) {
        report += [ "Private parcel" ];
        ++reportLength;
    }
    
    if ( ( flags & REGION_FLAG_ALLOW_DAMAGE ) && 
        ( parcel & PARCEL_FLAG_ALLOW_DAMAGE ) )
    {
        report += [ "High threat area." ];
        ++reportLength;
    }
    
    if ( flags & REGION_FLAG_FIXED_SUN ) {
        report += [ "Temporal anomaly; time not passing." ];
    } else {
        report += [ "Local time: " 
            + hhmm( zulu_time( (integer)llGetTimeOfDay() ) ) ];
    }
    
    string traffic;
    if ( ( flags & REGION_FLAG_BLOCK_FLY ) && 
        !( parcel & PARCEL_FLAG_ALLOW_FLY ) ) {
        traffic += "Traffic laws: Flight prohibited";
        ++reportLength;
    }
    if ( ! ( flags & REGION_FLAG_ALLOW_DIRECT_TELEPORT ) ) {
        if ( traffic ) {
            traffic += "; teleport through telehubs";
        } else {
            traffic = "Traffic laws: Teleport through telehubs";
            ++reportLength;
        }
    }
    if ( traffic ) report += [ traffic ];
    
    if ( !check_perms( parcel ) ) {
        report += [ "Constructs inhibited" ];
        ++reportLength;
    }
    
    queryStr1 = "Rating: ";
    queryID1 = llRequestSimulatorData( llGetRegionName(), DATA_SIM_RATING );
    queryStr2 = "Owned by: ";
    queryID2 = find_name( llList2Key( details, 1 ), queryStr2 );
}

agent_probe( key target )
{
    probeMode = PERSON;
    reportLength = 7;
    common_probe( target );
    
    report = [ "Scanning secondlife:///app/agent/" + (string)target 
        + "/about" ] + report;
    vector bounds = llGetAgentSize( target );
    bounds.z *= 1.1057;
    //bounds.z += 0.17;
    float mass = llGetObjectMass( target );
    integer height = llFloor( bounds.z * 100.0 / 2.51 );
    report += [ "    Height: " + llGetSubString( (string)bounds.z, 0, 3 )
        + "m (" + (string)( height / 12 ) + "'" 
            + (string)( height % 12 ) + "\")"
        + "; Mass: " + llGetSubString( (string)mass, 0, 3 ) ];
    
    queryID1 = llRequestAgentData( target, DATA_BORN );
    queryID2 = llRequestAgentData( target, DATA_PAYINFO );
    llSetTimerEvent( WAIT );
}

object_probe( key target )
{
    probeMode = THING;
    reportLength = 7;
    common_probe( target );
    
    report = [ "Scanning " + llKey2Name( target ) ] + report;
    
    list boundingBox = llGetBoundingBox( target );
    vector size = llList2Vector( boundingBox, 1 ) 
        - llList2Vector( boundingBox, 0 );
    report += [ "    Dimensions: " +
        llGetSubString( (string)size.x, 0, 2 ) + " × " +
        llGetSubString( (string)size.y, 0, 2 ) + " × " +
        llGetSubString( (string)size.z, 0, 2 ) + "m"
        ];
    
    list details = llGetObjectDetails( target, 
        [ OBJECT_OWNER, OBJECT_CREATOR, OBJECT_GROUP, 
        OBJECT_PRIM_EQUIVALENCE ] );
    report += [ "    Mass: " + 
        llGetSubString( (string)llGetObjectMass( target ), 0, 3 )
        + "; Land Impact: " + (string)llList2Integer( details, 3 ) ];
    
    // use these with Viewer 2 or higher
    report += "    Creator:  secondlife:///app/agent/" 
        + llList2String( details, 1 ) + "/inspect"; 
    if ( llList2Key( details, 0 ) ) {
        report += "    Owner: secondlife:///app/agent/" 
            + llList2String( details, 0 ) + "/inspect";
        report += "    Group: secondlife:///app/group/"
            + llList2String( details, 2 ) + "/inspect";
        reportLength++;
    } else {
        report += "    Group (probably owner): secondlife:///app/group/"
            + llList2String( details, 2 ) + "/inspect";
    }
    make_report();
    llSetTimerEvent( WAIT );
}

common_probe( key target )
{
    list details = llGetObjectDetails( target, [ OBJECT_NAME, OBJECT_POS,
        OBJECT_TOTAL_SCRIPT_COUNT, OBJECT_SCRIPT_MEMORY, OBJECT_SCRIPT_TIME ] );
    llMessageLinked( status, COMMUNICATION_MASK,
        llDumpList2String( [ "status", 
            "Scanning " + llList2String( details, 0 ), 10.0 ], 
            LINK_MSG_DELIM ),
        owner );
    
    vector where = llList2Vector( details, 1 );
    vector here = llGetPos();
    float range = llVecDist( where, here );
    integer bearing;
    if ( range ) {
        bearing = llRound( llAtan2( (where.x - here.x) / range, 
            (where.y - here.y) / range ) * RAD_TO_DEG );
    } else {
        bearing = 0;
    }
    string dA = (string)llRound( where.z - here.z );
    if ( (integer)dA >= 0 ) dA = "+" + dA;
    report += [ "    Bearing " + (string)bearing + "°, range " 
        + (string)llRound( range )
        + "m, altitude " + (string)llRound( where.z ) 
        + "m (" + dA + ")" ];
    report += [ "      " + "[secondlife:///app/worldmap/" 
        + llEscapeURL(llGetRegionName())
        + "/" + (string)llRound(where.x) 
        + "/" + (string)llRound( where.y ) 
        + "/" + (string)llRound( where.z ) 
        + "]" 
        ];
    report += [ "      [secondlife:///app/teleport/"
        + llEscapeURL( llGetRegionName() )
        + "/" + (string)llRound(where.x) 
        + "/" + (string)llRound( where.y ) 
        + "/" + (string)llRound( where.z )
        + "]"
        ];
    if ( llList2Float( details, 3 ) > 1048576 ) {
        report += [ "    " + (string)llRound( llList2Float(details, 3) / 1048576.0 )
            + "MB memory in " 
            + (string)llList2Integer( details, 2 ) + " scripts, using "
            + (string)( 1000.0 * llList2Float( details, 4 ) ) + " ms CPU/frame." ];
    } else {
        report += [ "    " + (string)llRound( llList2Float(details, 3) / 1024.0 )
            + "kB memory in " 
            + (string)llList2Integer( details, 2 ) + " scripts, using "
            + (string)( 1000.0 * llList2Float( details, 4 ) ) + " ms CPU/frame." ];
    }
}

key find_name( key who, string prefix )
{
    string name = llKey2Name( who );
    if ( name ) {
        report += [ prefix + name + " (nearby)" ];
        return NULL_KEY;
    }
    return llRequestAgentData( who, DATA_NAME );
}

make_report()
{
    if ( llGetListLength( report ) >= reportLength &&
        report != [] ) 
    {
        llMessageLinked( comm, COMMUNICATION_MASK,
            llDumpList2String( ["say"] + llDumpList2String( report, "\n" ),
                LINK_MSG_DELIM ), llGetKey() );
        report = [];
    }
}

dataserver_report( key query, string data )
{
    if ( probeMode == PERSON ) {
        if ( query == queryID1 ) {
            // Date of birth info
            string t = llGetTimestamp();
            list tNow = llParseString2List( t, ["T"], [] );
            string nowtime = llList2String( tNow, 0 );
            report += [ "    Born: " + data +
                " (" + 
                (string)( to_days( nowtime ) - to_days( data ) ) +
                " days ago)" ];
        } else if ( query == queryID2 ) {
            // Payment info
            integer info = (integer)data;
            if ( info ) {
                report += [ "    Identity validated" ];
            } else {
                report += [ "    No payment information on file" ];
            }
        }
    } else {
        if ( query == queryID1 ) {
            report += [ queryStr1 + data ];
        } else if ( query == queryID2 ) {
            report += [ queryStr2 + data ];
        }
    }
    make_report();
}

string hhmm( integer seconds )
{
    string time = (string)( seconds / 3600 );
    integer minutes = ( seconds % 3600 ) / 60;
    if ( minutes < 10 ) time += ":0" + (string)minutes;
    else time += ":" + (string)minutes;
    if ( seconds < 43200 ) time += " AM";
    else time += " PM";
    return time;
}

integer zulu_time( integer seconds ) {
    if ( seconds < 1800 ) {
        return seconds * 12;
    } else if ( seconds < 64800 ) {
        return ( seconds * 4 ) + 21600;
    } else {
        return ( seconds * 12 ) + 64800;
    }
}

integer to_days( string calt )
{
    integer result;
    list parseDate = llParseString2List( calt, ["-"], []);
    integer year = llList2Integer(parseDate, 0);
    result = (year-2000) * 365;
    list days = [ 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 ];
    result += llList2Integer( days, (llList2Integer( parseDate, 1 ) - 1 ) );
    result += llFloor( year / 4 );
    result += llList2Integer( parseDate, 2 );
    return result;
}

integer check_scripts( integer flags ) {
    if ( flags & PARCEL_FLAG_ALLOW_SCRIPTS )
        return TRUE;
    else if ( flags & PARCEL_FLAG_ALLOW_GROUP_SCRIPTS ) {
        key parcelGroup = llList2Key( 
                llGetParcelDetails( llGetPos(), [ PARCEL_DETAILS_GROUP ] )
                , 0 );
        if ( parcelGroup == group ) {
            return TRUE;
        }
    }
    return FALSE;
}

integer check_perms( integer parcel ) {
    if ( llOverMyLand( llGetOwner() ) ) return TRUE;

    if ( !check_scripts( parcel ) ) return FALSE;

    if ( PARCEL_FLAG_ALLOW_CREATE_OBJECTS  & parcel )
        return TRUE;
    else if ( PARCEL_FLAG_ALLOW_CREATE_GROUP_OBJECTS & parcel ) {
        key parcelGroup = llList2Key( 
                llGetParcelDetails( llGetPos(), [ PARCEL_DETAILS_GROUP ] )
                , 0 );
        if ( parcelGroup == group ) {
            return TRUE;
        }
    }
    return FALSE;
}

string nsew( float angle )
{
    if ( angle < 0. )
        angle += 360.;
    angle += 22.5;
    if ( angle < 45. )
        return "N";
    else if ( angle < 90. )
        return "NE";
    else if ( angle < 135. )
        return "E";
    else if ( angle < 180. )
        return "SE";
    else if ( angle < 225. )
        return "S";
    else if ( angle < 270. )
        return "SW";
    else if ( angle < 315. )
        return "W";
    else if ( angle < 360. )
        return "NW";
    else
        return "N";
}

set_lit( integer prim, integer on )
{
    if ( on ) {
        llSetLinkColor( prim, llList2Vector( llGetLinkPrimitiveParams(
            LINK_ROOT, [ PRIM_COLOR, LIT_FACE ] ), 0 ), ALL_SIDES );
    } else {
        llSetLinkColor( prim, llList2Vector( llGetLinkPrimitiveParams(
            LINK_ROOT, [ PRIM_COLOR, DIM_FACE ] ), 0 ), ALL_SIDES );
    }
}

key get_target()
{
    return (key)llList2String( 
        llGetLinkPrimitiveParams( targetPrim, [ PRIM_DESC ] )
        , 0 );
}

set_target( key id )
{
    llSetLinkPrimitiveParamsFast( targetPrim,
        [ PRIM_DESC, (string)id ] );
    llMessageLinked( LINK_SET, BROADCAST_MASK, 
        llDumpList2String( [ "trgt", id ], LINK_MSG_DELIM ),
        llGetKey() );
}

integer comm = LINK_ROOT;               // Where are the prims?
integer status = LINK_ALL_OTHERS;
integer targetPrim;
key owner;

list displayPrims;              // Prim numbers for line displays
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

display_prims() {               // Identify the prims used for sensor display
    integer i;
    integer c;
    list names;
    c = llGetNumberOfPrims() + 1;
    displayPrims = [];
    list parsed;
    string name;
    for ( i=0; i < c; ++i )
    {
        parsed = llParseString2List(llGetLinkName(i),["::"],[]);
        name = llToLower( llList2String( parsed, 0 ) );
        if ( name == "display" )
        {
            displayPrims += [ i ];
        }
    }
}

default
{
    state_entry()
    {
        list prims = get_link_numbers( [ "target" ] );
        targetPrim = llList2Integer( prims, 0 );
        status = LINK_ROOT;
        owner = llGetOwner();
        display_prims();
        //llWhisper( DEBUG_CHANNEL, llGetScriptName() + " initialized; " 
        //    + (string)llGetFreeMemory() + " bytes free." );
    }

    link_message( integer source, integer flag, string message, key id )
    {
        if ( flag & SCAN_MASK ) {
            string cmd = llGetSubString( message, 0, 3 );
            
            if ( cmd == "sens" ) {
                scan_commands( llParseString2List( message,DELIMIT,[]) );
            } else if ( cmd == "rset" ) {
                llResetScript();
            } else if ( cmd == "diag" ) {
                llWhisper( 0, "/me TARGET LOCK" +
                    "\n" + (string)llGetFreeMemory() + " bytes free."
                    );
            }
        }
    }
    
    dataserver( key query, string data )
    {
        dataserver_report( query, data );
    }
    
    touch_end( integer d )
    {
        vector touchPos = llDetectedTouchUV( 0 );
        integer row = (integer)(touchPos.y * 16);
        string cmd = llList2String( llGetLinkPrimitiveParams( 
                    llList2Integer( displayPrims, row ),
                [ PRIM_DESC ] ),
            0 );
        llPlaySound( "46e2dd13-85b4-8c91-ab62-7d5c4dd16068", 0.5 );
        if ( (key)cmd == get_target() ) {
            set_target( NULL_KEY );
        } else {
            set_target( cmd );
        }
        llSleep( 0.75 );
        llStopSound();
    }
    timer()
    {
        if ( report ) {
            make_report();
        }
        llSetTimerEvent( 0. );
    }
}
