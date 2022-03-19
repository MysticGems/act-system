// ============================================================================
// Calm effect - lose target & focus (prevented by hope or willpower)         \
// by Jack Abraham                                                         \__
// ============================================================================

integer success;
integer listenHandle;
key target;
vector sitOffset = ZERO_VECTOR;
rotation sitRotation = ZERO_ROTATION;

// -------------------------------------------------------------------------
string attribute = "";
string skill = "";
string trait = "";
float mod = 0.0;
float busy = 0.0;
string startMsg = "";

test()
{
    llListenRemove( listenHandle );
    listenHandle = llListen( key2channel( llGetKey() ), 
        "", NULL_KEY, "" );
    if ( attribute ) {
        send( [ "a!act", llGetKey(), 0, attribute, skill, trait, mod ] );
    } else if ( trait ) {
        send( [ "a!trt", llGetKey(), 0, trait ] );
    }
    if ( startMsg ) {
        llRegionSayTo( target, 0, startMsg );
    }
    llSetTimerEvent( busy );
}

string giveItem = "";
string successMsg = "";
string failMsg = "";

results( integer win )
{
    if ( win ) {
        if ( giveItem ) {
            llGiveInventory( target, giveItem );
        }
        if ( successMsg ) {
            llRegionSayTo( target, 0, successMsg );
        }
    } else {
        if ( failMsg ) {
            llRegionSayTo( target, 0, failMsg );
        }
    }
}

// -------------------------------------------------------------------------
// Act! Communications

string ACT_DELIM = ":";

send( list msg )
{
    llRegionSay( key2channel( target ), llDumpList2String( [ target ] +
        msg, ACT_DELIM ) );
}

integer key2channel( key who ) // -- Act! communications channel ----------
{
    return -1 * (integer)( "0x" + llGetSubString( (string)who, -12, -5 ) );
}

// -------------------------------------------------------------------------
// Configuration items
string CONFIG = "*Act!";                // Notecard with configuration
key queryID;                            // Current query
integer noteLine = 0;                   // Notecard line

// ============================================================================

default
{
    state_entry()
    {
        if ( llGetInventoryType( CONFIG ) == INVENTORY_NOTECARD ) {
            noteLine = 0;
            queryID = llGetNotecardLine( CONFIG, noteLine );
        }
    }
    
    dataserver( key query, string data )
    {
        if ( query == queryID ) {
            if ( data != EOF ) {
                data = llList2String(
                    llParseStringKeepNulls( data, [ "//" ], [] ),
                    0 );
                if ( data ) {
                    list keyval = llParseStringKeepNulls( data, ["="], [] );
                    string dataKey = llStringTrim( llList2String( keyval, 0 ), 
                            STRING_TRIM );
                    string dataVal = llStringTrim( 
                            llList2String( keyval, 1 ), 
                            STRING_TRIM );
                    if ( dataKey == "trait" ) {
                        trait = dataVal;
                    } else if ( dataKey == "attribute" ) {
                        attribute = dataVal;
                    } else if ( dataKey == "skill" ) {
                        skill = dataVal;
                    } else if ( dataKey == "mod" ) {
                        mod = (float)dataVal;
                    } else if ( dataKey == "sit offset" ) {
                        sitOffset = (vector)dataVal;
                    } else if ( dataKey == "sit rotation" ) {
                        sitRotation = llEuler2Rot( 
                            (vector)dataVal * DEG_TO_RAD );
                    } else if ( dataKey == "busy" ) {
                        busy = (float)dataVal;
                    } else if ( dataKey == "give" ) {
                        giveItem = dataVal;
                        if ( llGetInventoryType( giveItem ) != INVENTORY_NONE )
                        {
                            integer perm = llGetInventoryPermMask( giveItem, 
                                MASK_OWNER );
                            if ( !( perm & PERM_TRANSFER ) )
                            {
                                llOwnerSay( "ERROR: " + giveItem +
                                    " cannot be given." );
                            } else if ( !(perm & PERM_COPY ) ) {
                                llOwnerSay( "WARNING: " + giveItem +
                                    " is no-copy." );
                            }
                        } else {
                            llOwnerSay( "ERROR: Nothing to give." );
                        }
                    } else if ( dataKey == "success message" ) {
                        successMsg = dataVal;
                    } else if ( dataKey == "fail message" ) {
                        failMsg = dataVal;
                    } else if ( dataKey == "start message" ) {
                        startMsg = dataVal;
                    }
                }
                ++noteLine;
                queryID = llGetNotecardLine( CONFIG, noteLine );
            } else {
                if ( sitOffset != ZERO_VECTOR ) {
                    llSitTarget( sitOffset, sitRotation );
                }
                if ( attribute != "" && trait != "" ) {
                    llOwnerSay( "ERROR: Nothing to test!" );
                    return;
                }
                llSetMemoryLimit( llGetUsedMemory() + 512 );
                llOwnerSay( (string)llGetMemoryLimit() + " bytes used; ready." );
            }
        }
    }
    
    changed( integer change )
    {
        if ( change & CHANGED_LINK ) {
            target = llAvatarOnSitTarget();
            if ( target ) {
                test();
            } else {
                llListenRemove( listenHandle );
            }
        }
        if ( change & CHANGED_INVENTORY ) {
            llResetScript();
        }
    }
    
    touch_end( integer d )
    {
        if ( sitOffset == ZERO_VECTOR ) {
            target = llDetectedKey(0);
            test();
        } else {
            llRegionSayTo( llDetectedKey(0), 0, "To use me, sit on me." );
        }
    }
    
    listen( integer channel, string who, key id, string msg )
    {
        if ( llGetOwnerKey( id ) == target ) {
            list parsed = llParseString2List( msg, [ ACT_DELIM ], [] );
            success = !(llListFindList( parsed, ["FAIL"] ) > -1);
            llListenRemove( listenHandle );
            if ( busy < 0.1 ) {
                results( success );
            }
        }
    }

    timer()
    {
        if ( sitOffset != ZERO_VECTOR ) {
            if ( llAvatarOnSitTarget() != target ) {
                return;
            }
        }
        results( success );
        llResetScript();
    }    
}
