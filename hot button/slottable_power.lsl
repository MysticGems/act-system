// ===========================================================================
// Slottable power placeholder                                               \
// By Jack Abraham                                                        \__ 
// ===========================================================================

integer REMOTE_SCRIPT_PIN = 3694683;
integer UPDATE_CHANNEL = -4294967;
integer VERSION = 1;

float INDUCTION_TIME = 5.;
float COOLDOWN_TIME = 5.;

start_ability()
// Start ability activity; this executes during induction
{
    llOwnerSay( llGetScriptName() + " started" );
}

fire_ability()
// Actually do the things we do; this fires after induction if not aborted
{
    llOwnerSay( llGetScriptName() + " fired" );
}

abort_ability()
// If the ability is aborted, do cleanup
{
    llOwnerSay( llGetScriptName() + " aborted" );
}

integer FACE = 0;                       // Face toward the owner
integer UI_MASK             = 0x80000000;
integer COMBAT_MASK         = 0x8000000;

// ===========================================================================

default
{
    state_entry()
    {
        if ( llGetInventoryNumber( INVENTORY_TEXTURE ) ) {
            llSetTexture( llGetInventoryName( INVENTORY_TEXTURE, 0 ), FACE );
        }
        llSetRemoteScriptAccessPin( 0 );
        integer i;
        integer c = llGetInventoryNumber( INVENTORY_SCRIPT );
        llAllowInventoryDrop( 0 );
        for ( i=0; i < c; i++ ) {
            if ( llGetInventoryName( INVENTORY_SCRIPT, i ) 
                != llGetScriptName() ) 
            {
                llRemoveInventory( llGetInventoryName( INVENTORY_SCRIPT, i ) );
            }
        }
        if ( llGetAttached() ) {
            llRequestPermissions( llGetOwner(), 
                PERMISSION_TRIGGER_ANIMATION | PERMISSION_TAKE_CONTROLS );
        } else {
            llOwnerSay( "Wear me to finish initializing your ability." );
        }
    }
    
    attach( key id )
    {
        if ( id ) {
            llRequestPermissions( llGetOwner(), 
                PERMISSION_TRIGGER_ANIMATION | PERMISSION_TAKE_CONTROLS );
        }
    }
    
    run_time_permissions( integer perm )
    {
        if ( perm & ( PERMISSION_TRIGGER_ANIMATION | PERMISSION_TAKE_CONTROLS ))
        {
            llTakeControls( CONTROL_ML_LBUTTON | CONTROL_LBUTTON, FALSE, TRUE );
            state active;
        }
    }
    
    state_exit()
    {
        llMessageLinked( LINK_SET, UI_MASK, "hotbar ready", llGetKey() );
    }
}

state update
{
    state_entry()
    {
        llSetColor( <0.5, 0.5, 0.5>, ALL_SIDES );
    }
    
    link_message( integer sender, integer num, string msg, key id )
    {
        if ( num & UI_MASK ) {
            if ( msg == "hotbar ready" ) {
                state active;
            }
        } else if ( msg == "fmem" ) {
            llMessageLinked( sender, llGetFreeMemory(), "fmem", id );
        } else if ( msg == "rset" ) {
            llResetScript();
        } else if ( msg == "diag" ) {
            llWhisper( 0, llGetScriptName() + " " + (string)llGetFreeMemory()
                + " bytes free." );
        }
    }
    
    touch_end( integer d )
    {
        llSetColor( <1.0, 1.0, 1.0>, ALL_SIDES );
        integer i;
        integer c = llGetInventoryNumber( INVENTORY_ALL );
        llAllowInventoryDrop( 0 );
        for ( i=0; i < c; i++ ) {
            if ( llGetInventoryName( INVENTORY_ALL, i ) 
                != llGetScriptName() ) 
            {
                llRemoveInventory( llGetInventoryName( INVENTORY_ALL, i ) );
            }
        }
        llAllowInventoryDrop( TRUE );
        llSetRemoteScriptAccessPin( REMOTE_SCRIPT_PIN );
        llSetTimerEvent( 5.0 );
    }

    timer()
    {
        llWhisper( UPDATE_CHANNEL, "update|" 
            + (string)VERSION + "|" + llGetScriptName() );
    }
    
    on_rez( integer d )
    {
        llOwnerSay( llGetScriptName() + " is in the middle of an update.  Rez your updater to complete the update." );        
    }
    
    changed( integer change )
    {
        if ( change & ( CHANGED_INVENTORY | CHANGED_ALLOWED_DROP ) ) {
            if ( llGetInventoryNumber( INVENTORY_SCRIPT ) > 1 ) {
                llSetTimerEvent( 0. );
                llSetScriptState( llGetScriptName(), FALSE );
            }
        }
    }
}

// ===========================================================================
// Actual events for doing cool stuff

state active
{
    state_entry()
    {
        llSetAlpha( 1.0, ALL_SIDES );
        llSetColor( <0.5, 0.5, 0.5>, ALL_SIDES );
        llSetColor( <1.0, 1.0, 1.0>, FACE );
        llOwnerSay( llGetScriptName() + " ready." );
    }
    
    touch_end( integer d )
    {
        integer busy = llList2Integer( 
            llGetLinkPrimitiveParams( LINK_ROOT, [ PRIM_MATERIAL ] ), 0 );
        if ( !busy ) {
            llSetColor( <1.0, 1.0, 1.0>, ALL_SIDES );
            if ( INDUCTION_TIME ) {
                llSetLinkPrimitiveParamsFast( LINK_ROOT, 
                    [ PRIM_MATERIAL, TRUE ] );
                llSetTimerEvent( INDUCTION_TIME );
                start_ability();
            } else {
                fire_ability();
                state cooldown;
            }
        } else {
            llOwnerSay( "Busy." );
        }
    }
    
    link_message( integer sender, integer num, string msg, key id )
    {
        if ( num & COMBAT_MASK ) {
            if ( msg == "abort" ) {
                abort_ability();
                llSetLinkPrimitiveParamsFast( LINK_ROOT,
                    [ PRIM_MATERIAL, FALSE ] );
                llSetTimerEvent( 0.0 );
                llSetColor( <0.5, 0.5, 0.5>, ALL_SIDES );
                llSetColor( <1.0, 1.0, 1.0>, FACE );
            }
        } else if ( num & UI_MASK ) {
            if ( msg == "hotbr" ) {
                state update;
            }
        } else if ( msg == "fmem" ) {
            llMessageLinked( sender, llGetFreeMemory(), "fmem", id );
        } else if ( msg == "rset" ) {
            llResetScript();
        } else if ( msg == "diag" ) {
            llWhisper( 0, llGetScriptName() + " " + (string)llGetFreeMemory()
                + " bytes free." );
        }
    }
    
    timer()
    {
        fire_ability();
        llSetLinkPrimitiveParamsFast( LINK_ROOT,
            [ PRIM_MATERIAL, FALSE ] );
        state cooldown;
    }
    
    state_exit()
    {
        llSetTimerEvent( COOLDOWN_TIME );
    }
}

state cooldown
{
    state_entry()
    {
        llSetColor( <0.5, 0.5, 0.5>, ALL_SIDES );
        if ( COOLDOWN_TIME ) {
            llSetTimerEvent( COOLDOWN_TIME );
        } else {
            state active;
        }
    }
    
    link_message( integer sender, integer num, string msg, key id )
    {
        if ( msg == "fmem" ) {
            llMessageLinked( sender, llGetFreeMemory(), "fmem", id );
        } else if ( msg == "rset" ) {
            llResetScript();
        } else if ( msg == "diag" ) {
            llWhisper( 0, llGetScriptName() + " " + (string)llGetFreeMemory()
                + " bytes free." );
        }
    }
    timer()
    {
        state active;
    }
    
    state_exit()
    {
        llSetTimerEvent( 0.0 );
    }
}

// Copyright ©2011 Jack Abraham and player, all rights reserved
// Contact Guardian Karu in Second Life for distribution rights.