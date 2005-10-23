/* -*- c -*-
 *
 * Copyright (C) 2004-2005 Daniel P. Berrange
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * $Id: DBus.xs,v 1.16 2005/10/15 14:21:47 dan Exp $
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <dbus/dbus.h>

#if PD_DO_DEBUG
#define PD_DEBUG(...) if (getenv("PD_DEBUG")) fprintf(stderr, __VA_ARGS__)
#else
#define PD_DEBUG(...)
#endif


/* The -1 is required by the contract for
   dbus_{server,connection}_allocate_slot 
   initialization */
dbus_int32_t connection_data_slot = -1;
dbus_int32_t server_data_slot = -1;

void
_object_release(void *obj) {
    PD_DEBUG("Releasing object count on %p\n", obj);
    SvREFCNT_dec((SV*)obj);
}

dbus_bool_t
_watch_generic(DBusWatch *watch, void *data, char *key, dbus_bool_t server) {
    SV *selfref;
    HV *self;
    SV **call;
    SV *h_sv;
    dSP;

    PD_DEBUG("Watch generic callback %p %p %s %d\n", watch, data, key, server);

    if (server) {
      selfref = (SV*)dbus_server_get_data((DBusServer*)data, server_data_slot);
    } else {
      selfref = (SV*)dbus_connection_get_data((DBusConnection*)data, connection_data_slot);
    }
    self = (HV*)SvRV(selfref);

    PD_DEBUG("Got owner %p\n", self);

    call = hv_fetch(self, key, strlen(key), 0);

    if (!call) {
      warn("Could not find watch callback %s for fd %d\n", 
           key, dbus_watch_get_fd(watch));
      return FALSE;
    }

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(selfref);
    h_sv = sv_newmortal();
    sv_setref_pv(h_sv, "Net::DBus::Binding::C::Watch", (void*)watch);
    XPUSHs(h_sv);
    PUTBACK;

    call_sv(*call, G_DISCARD);

    FREETMPS;
    LEAVE;

    return 1;
}

dbus_bool_t
_watch_server_add(DBusWatch *watch, void *data) {
    return _watch_generic(watch, data, "add_watch", 1);
}
void
_watch_server_remove(DBusWatch *watch, void *data) {
    _watch_generic(watch, data, "remove_watch", 1);
}
void
_watch_server_toggled(DBusWatch *watch, void *data) {
    _watch_generic(watch, data, "toggled_watch", 1);
}

dbus_bool_t
_watch_connection_add(DBusWatch *watch, void *data) {
    return _watch_generic(watch, data, "add_watch", 0);
}
void
_watch_connection_remove(DBusWatch *watch, void *data) {
    _watch_generic(watch, data, "remove_watch", 0);
}
void
_watch_connection_toggled(DBusWatch *watch, void *data) {
    _watch_generic(watch, data, "toggled_watch", 0);
}


dbus_bool_t
_timeout_generic(DBusTimeout *timeout, void *data, char *key, dbus_bool_t server) {
    SV *selfref;
    HV *self;
    SV **call;
    SV *h_sv;
    dSP;

    if (server) {
      selfref = (SV*)dbus_server_get_data((DBusServer*)data, server_data_slot);
    } else {
      selfref = (SV*)dbus_connection_get_data((DBusConnection*)data, connection_data_slot);
    }
    self = (HV*)SvRV(selfref);

    call = hv_fetch(self, key, strlen(key), 0);

    if (!call) {
      warn("Could not find timeout callback for %s\n", key);
      return FALSE;
    }

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs((SV*)selfref);
    h_sv = sv_newmortal();
    sv_setref_pv(h_sv, "Net::DBus::Binding::C::Timeout", (void*)timeout);
    XPUSHs(h_sv);
    PUTBACK;

    call_sv(*call, G_DISCARD);

    FREETMPS;
    LEAVE;

    return 1;
}

dbus_bool_t
_timeout_server_add(DBusTimeout *timeout, void *data) {
    return _timeout_generic(timeout, data, "add_timeout", 1);
}
void
_timeout_server_remove(DBusTimeout *timeout, void *data) {
    _timeout_generic(timeout, data, "remove_timeout", 1);
}
void
_timeout_server_toggled(DBusTimeout *timeout, void *data) {
    _timeout_generic(timeout, data, "toggled_timeout", 1);
}

dbus_bool_t
_timeout_connection_add(DBusTimeout *timeout, void *data) {
    return _timeout_generic(timeout, data, "add_timeout", 0);
}
void
_timeout_connection_remove(DBusTimeout *timeout, void *data) {
    _timeout_generic(timeout, data, "remove_timeout", 0);
}
void
_timeout_connection_toggled(DBusTimeout *timeout, void *data) {
    _timeout_generic(timeout, data, "toggled_timeout", 0);
}

void 
_connection_callback (DBusServer *server,
                      DBusConnection *new_connection,
                      void *data) {
    SV *selfref = (SV*)dbus_server_get_data((DBusServer*)data, server_data_slot);
    HV *self = (HV*)SvRV(selfref);
    SV **call;
    SV *value;
    dSP;

    call = hv_fetch(self, "_callback", strlen("_callback"), 0);

    if (!call) {
      warn("Could not find new connection callback\n");
      return;
    }

    PD_DEBUG("Created connection in callback %p\n", new_connection);
    /* The DESTROY method will de-ref it later */
    dbus_connection_ref(new_connection);

    value = sv_newmortal();
    sv_setref_pv(value, "Net::DBus::Binding::C::Connection", (void*)new_connection);

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(selfref);
    XPUSHs(value);
    PUTBACK;

    call_sv(*call, G_DISCARD);

    FREETMPS;
    LEAVE;    
}


DBusHandlerResult
_message_filter(DBusConnection *con,
                DBusMessage *msg,
                void *data) {
    SV *selfref;
    HV *self;
    SV *value;
    int count;
    int handled = 0;
    dSP;

    selfref = (SV*)dbus_connection_get_data(con, connection_data_slot);
    self = (HV*)SvRV(selfref);

    PD_DEBUG("Create message in filter %p\n", msg);
    PD_DEBUG("  Type %d\n", dbus_message_get_type(msg));
    PD_DEBUG("  Interface %s\n", dbus_message_get_interface(msg) ? dbus_message_get_interface(msg) : "");
    PD_DEBUG("  Path %s\n", dbus_message_get_path(msg) ? dbus_message_get_path(msg) : "");
    PD_DEBUG("  Member %s\n", dbus_message_get_member(msg) ? dbus_message_get_member(msg) : "");
    /* Will be de-refed in the DESTROY method */
    dbus_message_ref(msg);
    value = sv_newmortal();
    sv_setref_pv(value, "Net::DBus::Binding::C::Message", (void*)msg);

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs((SV*)selfref);
    XPUSHs(value);
    XPUSHs(data);
    PUTBACK;

    count = call_method("_message_filter", G_SCALAR);
    /* XXX POPi prints use of uninitialized value ?!?!?! */
if (0) {
    if (count == 1) {
      handled = POPi;
    } else {
      handled = 0;
    }
}
    FREETMPS;
    LEAVE;

    return handled ? DBUS_HANDLER_RESULT_HANDLED : DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

void
_filter_release(void *data) {
    SvREFCNT_dec(data);
}

void
_path_unregister_callback(DBusConnection *con,
                          void *data) {
    SvREFCNT_dec(data);
}

DBusHandlerResult
_path_message_callback(DBusConnection *con,
                       DBusMessage *msg,
                       void *data) {
    SV *self = (SV*)dbus_connection_get_data(con, connection_data_slot);
    SV *value;
    dSP;

    PD_DEBUG("Got message in callback %p\n", msg);
    PD_DEBUG("  Type %d\n", dbus_message_get_type(msg));
    PD_DEBUG("  Interface %s\n", dbus_message_get_interface(msg) ? dbus_message_get_interface(msg) : "");
    PD_DEBUG("  Path %s\n", dbus_message_get_path(msg) ? dbus_message_get_path(msg) : "");
    PD_DEBUG("  Member %s\n", dbus_message_get_member(msg) ? dbus_message_get_member(msg) : "");
    /* Will be de-refed in the DESTROY method */
    dbus_message_ref(msg);
    value = sv_newmortal();
    sv_setref_pv(value, "Net::DBus::Binding::C::Message", (void*)msg);

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(self);
    XPUSHs(value);
    PUTBACK;

    call_sv((SV*)data, G_DISCARD);

    FREETMPS;
    LEAVE;

    return DBUS_HANDLER_RESULT_HANDLED;
}

DBusObjectPathVTable _path_callback_vtable = {
	_path_unregister_callback,
	_path_message_callback,
	NULL,
	NULL,
        NULL,
        NULL
};

SV *
_sv_from_error (DBusError *error)
{
    HV *hv;

    if (!error) {
      warn ("error is NULL");
      return &PL_sv_undef;
    }
    
    if (!dbus_error_is_set (error)) {
      warn ("error is unset");
      return &PL_sv_undef;
    }
    
    hv = newHV ();
    
    /* map DBusError attributes to hash keys */
    hv_store (hv, "name", 4, newSVpv (error->name, 0), 0);
    hv_store (hv, "message", 7, newSVpv (error->message, 0), 0);
    
    return sv_bless (newRV_noinc ((SV*) hv), gv_stashpv ("Net::DBus::Error", TRUE));
}

void
_croak_error (DBusError *error)
{
    sv_setsv (ERRSV, _sv_from_error (error));
    
    /* croak does not return, so we free this now to avoid leaking */
    dbus_error_free (error);
    
    croak (Nullch);
}

void
_populate_constant(HV *href, char *name, int val)
{
    hv_store(href, name, strlen(name), newSViv(val), 0);
}

#define REGISTER_CONSTANT(name, key) _populate_constant(constants, #key, name)

MODULE = Net::DBus		PACKAGE = Net::DBus		

PROTOTYPES: ENABLE
BOOT:
    {
        HV *constants;

        /* not the 'standard' way of doing perl constants, but a lot easier to maintain */

        constants = perl_get_hv("Net::DBus::Binding::Bus::_constants", TRUE);
        REGISTER_CONSTANT(DBUS_BUS_SYSTEM, SYSTEM);
        REGISTER_CONSTANT(DBUS_BUS_SESSION, SESSION);
        REGISTER_CONSTANT(DBUS_BUS_STARTER, STARTER);

        constants = perl_get_hv("Net::DBus::Binding::Message::_constants", TRUE);
        REGISTER_CONSTANT(DBUS_TYPE_ARRAY, TYPE_ARRAY);
        REGISTER_CONSTANT(DBUS_TYPE_BOOLEAN, TYPE_BOOLEAN);
        REGISTER_CONSTANT(DBUS_TYPE_BYTE, TYPE_BYTE);
        REGISTER_CONSTANT(DBUS_TYPE_DOUBLE, TYPE_DOUBLE);
        REGISTER_CONSTANT(DBUS_TYPE_INT32, TYPE_INT32);
        REGISTER_CONSTANT(DBUS_TYPE_INT64, TYPE_INT64);
        REGISTER_CONSTANT(DBUS_TYPE_INVALID, TYPE_INVALID);
        REGISTER_CONSTANT(DBUS_TYPE_STRUCT, TYPE_STRUCT);
        REGISTER_CONSTANT(DBUS_TYPE_SIGNATURE, TYPE_SIGNATURE);
        REGISTER_CONSTANT(DBUS_TYPE_OBJECT_PATH, TYPE_OBJECT_PATH);
        REGISTER_CONSTANT(DBUS_TYPE_DICT_ENTRY, TYPE_DICT_ENTRY);
        REGISTER_CONSTANT(DBUS_TYPE_STRING, TYPE_STRING);
        REGISTER_CONSTANT(DBUS_TYPE_UINT32, TYPE_UINT32);
        REGISTER_CONSTANT(DBUS_TYPE_UINT64, TYPE_UINT64);
        REGISTER_CONSTANT(DBUS_TYPE_VARIANT, TYPE_VARIANT);

	REGISTER_CONSTANT(DBUS_MESSAGE_TYPE_METHOD_CALL, MESSAGE_TYPE_METHOD_CALL);
	REGISTER_CONSTANT(DBUS_MESSAGE_TYPE_METHOD_RETURN, MESSAGE_TYPE_METHOD_RETURN);
	REGISTER_CONSTANT(DBUS_MESSAGE_TYPE_ERROR, MESSAGE_TYPE_ERROR);
	REGISTER_CONSTANT(DBUS_MESSAGE_TYPE_SIGNAL, MESSAGE_TYPE_SIGNAL);
	REGISTER_CONSTANT(DBUS_MESSAGE_TYPE_INVALID, MESSAGE_TYPE_INVALID);
	
        constants = perl_get_hv("Net::DBus::Binding::Watch::_constants", TRUE);
        REGISTER_CONSTANT(DBUS_WATCH_READABLE, READABLE);
        REGISTER_CONSTANT(DBUS_WATCH_WRITABLE, WRITABLE);
        REGISTER_CONSTANT(DBUS_WATCH_ERROR, ERROR);
        REGISTER_CONSTANT(DBUS_WATCH_HANGUP, HANGUP);

        dbus_connection_allocate_data_slot(&connection_data_slot);
        dbus_server_allocate_data_slot(&server_data_slot);
    }


MODULE = Net::DBus::Binding::Connection		PACKAGE = Net::DBus::Binding::Connection

PROTOTYPES: ENABLE

DBusConnection *
_open(address)
        char *address;
    PREINIT:
        DBusError error;
        DBusConnection *con;
    CODE:
        dbus_error_init(&error);
        con = dbus_connection_open(address, &error);
        if (!con) {
          _croak_error (&error);
        }
        RETVAL = con;
    OUTPUT:
        RETVAL

MODULE = Net::DBus::Binding::C::Connection		PACKAGE = Net::DBus::Binding::C::Connection

void
_set_owner(con, owner)
        DBusConnection *con;
        SV *owner;
    CODE:
        SvREFCNT_inc(owner);
        dbus_connection_set_data(con, connection_data_slot, owner, _object_release);

void
dbus_connection_disconnect(con)
        DBusConnection *con;

int
dbus_connection_get_is_connected(con)
        DBusConnection *con;

int
dbus_connection_get_is_authenticated(con)
        DBusConnection *con;

void
dbus_connection_flush(con)
        DBusConnection *con;

int
_send(con, msg)
        DBusConnection *con;
        DBusMessage *msg;
    PREINIT:
        dbus_uint32_t serial;
    CODE:
        if (!dbus_connection_send(con, msg, &serial)) {
          croak("not enough memory to send message");
        }
        RETVAL = serial;
    OUTPUT:
        RETVAL

DBusMessage *
_send_with_reply_and_block(con, msg, timeout)
        DBusConnection *con;
        DBusMessage *msg;
        int timeout;
    PREINIT:
        DBusMessage *reply;
        DBusError error;
    CODE:
        dbus_error_init(&error);
        if (!(reply = dbus_connection_send_with_reply_and_block(con, msg, timeout, &error))) {
          _croak_error(&error);
        }
        PD_DEBUG("Create msg reply %p\n", reply);
        PD_DEBUG("  Type %d\n", dbus_message_get_type(reply));
        PD_DEBUG("  Interface %s\n", dbus_message_get_interface(reply) ? dbus_message_get_interface(reply) : "");
        PD_DEBUG("  Path %s\n", dbus_message_get_path(reply) ? dbus_message_get_path(reply) : "");
        PD_DEBUG("  Member %s\n", dbus_message_get_member(reply) ? dbus_message_get_member(reply) : "");
        // XXX needed ?
        //dbus_message_ref(reply);
        RETVAL = reply;
    OUTPUT:
        RETVAL

DBusMessage *
dbus_connection_borrow_message(con)
        DBusConnection *con;

void
dbus_connection_return_message(con, msg)
        DBusConnection *con;
        DBusMessage *msg;

void
dbus_connection_steal_borrowed_message(con, msg)
        DBusConnection *con;
        DBusMessage *msg;

DBusMessage *
dbus_connection_pop_message(con)
        DBusConnection *con;

void
_dispatch(con)
        DBusConnection *con;
    CODE:
        while(dbus_connection_dispatch(con) == DBUS_DISPATCH_DATA_REMAINS);

void
_set_watch_callbacks(con)
        DBusConnection *con;
    CODE:
        if (!dbus_connection_set_watch_functions(con, 
                                                 _watch_connection_add, 
                                                 _watch_connection_remove, 
                                                 _watch_connection_toggled, 
                                                 con, NULL)) {
          croak("not enough memory to set watch functions on connection");
        }

void
_set_timeout_callbacks(con)
        DBusConnection *con;
    CODE:
        if (!dbus_connection_set_timeout_functions(con, 
                                                   _timeout_connection_add, 
                                                   _timeout_connection_remove, 
                                                   _timeout_connection_toggled, 
                                                   con, NULL)) {
          croak("not enough memory to set timeout functions on connection");
        }

void
_register_object_path(con, path, code)
        DBusConnection *con;
        char *path;
        SV *code;
    CODE:
        SvREFCNT_inc(code);
        if (!(dbus_connection_register_object_path(con, path, &_path_callback_vtable, code))) {
          croak("not enough memory to register object path");
        }

void
_add_filter(con, code)
        DBusConnection *con;
        SV *code;
    CODE:
        SvREFCNT_inc(code);
	PD_DEBUG("Adding filter %p\n", code);
        dbus_connection_add_filter(con, _message_filter, code, _filter_release);

dbus_bool_t
dbus_bus_register(con)
        DBusConnection *con;
    PREINIT:
        DBusError error;
        int reply;
    CODE:
        dbus_error_init(&error);
        if (!(reply = dbus_bus_register(con, &error))) {
          _croak_error(&error);
        }
        RETVAL = reply;

void
dbus_bus_add_match(con, rule)
        DBusConnection *con;
        char *rule;
    PREINIT:
        DBusError error;
    CODE:
        dbus_error_init(&error);
	PD_DEBUG("Adding match %s\n", rule);
        dbus_bus_add_match(con, rule, &error);
	if (dbus_error_is_set(&error)) {
	  _croak_error(&error);
 	}

void
dbus_bus_remove_match(con, rule)
        DBusConnection *con;
        char *rule;
    PREINIT:
        DBusError error;
    CODE:
        dbus_error_init(&error);
	PD_DEBUG("Removeing match %s\n", rule);
        dbus_bus_remove_match(con, rule, &error);
	if (dbus_error_is_set(&error)) {
	  _croak_error(&error);
 	}

const char *
dbus_bus_get_unique_name(con)
	DBusConnection *con;

int
dbus_bus_request_name(con, service_name)
        DBusConnection *con;
        char *service_name;
    PREINIT:
        DBusError error;
        int reply;
    CODE:
        dbus_error_init(&error);
        if (!(reply = dbus_bus_request_name(con, service_name, 0, &error))) {
          _croak_error(&error);
        }
        RETVAL = reply;

void
DESTROY(con)
        DBusConnection *con;
   CODE:
        PD_DEBUG("Destroying connection %p\n", con);
        dbus_connection_disconnect(con);
        // XXX do we need this or not ?
        //dbus_connection_unref(con);


MODULE = Net::DBus::Binding::Server		PACKAGE = Net::DBus::Binding::Server

PROTOTYPES: ENABLE

DBusServer *
_open(address)
        char *address;
    PREINIT:
        DBusError error;
        DBusServer *server;
    CODE:
        dbus_error_init(&error);
        server = dbus_server_listen(address, &error);
        PD_DEBUG("Created server %p on address %s", server, address);
        if (!server) {
          _croak_error(&error);
        }
        if (!dbus_server_set_auth_mechanisms(server, NULL)) {
            croak("not enough memory to server auth mechanisms");
        }
        RETVAL = server;
    OUTPUT:
        RETVAL


MODULE = Net::DBus::Binding::C::Server		PACKAGE = Net::DBus::Binding::C::Server

void
_set_owner(server, owner)
        DBusServer *server;
        SV *owner;
    CODE:
        SvREFCNT_inc(owner);
        dbus_server_set_data(server, server_data_slot, owner, _object_release);

void
dbus_server_disconnect(server)
        DBusServer *server;

int
dbus_server_get_is_connected(server)
        DBusServer *server;

void
_set_watch_callbacks(server)
        DBusServer *server;
    CODE:
        if (!dbus_server_set_watch_functions(server, 
                                             _watch_server_add, 
                                             _watch_server_remove, 
                                             _watch_server_toggled, 
                                             server, NULL)) {
          croak("not enough memory to set watch functions on server");
        }


void
_set_timeout_callbacks(server)
        DBusServer *server;
    CODE:
        if (!dbus_server_set_timeout_functions(server, 
                                               _timeout_server_add, 
                                               _timeout_server_remove, 
                                               _timeout_server_toggled, 
                                               server, NULL)) {
          croak("not enough memory to set timeout functions on server");
        }


void
_set_connection_callback(server)
        DBusServer *server;
    CODE:
        dbus_server_set_new_connection_function(server, 
                                                _connection_callback,
                                                server, NULL);

void
DESTROY(server)
        DBusServer *server;
   CODE:
        PD_DEBUG("Destroying server %p\n", server);
        dbus_server_unref(server);


MODULE = Net::DBus::Binding::Bus		PACKAGE = Net::DBus::Binding::Bus

PROTOTYPES: ENABLE

DBusConnection *
_open(type)
        DBusBusType type;
    PREINIT:
        DBusError error;
        DBusConnection *con;
    CODE:
        dbus_error_init(&error);
        con = dbus_bus_get(type, &error);
        if (!con) {
          _croak_error(&error);
        }
        RETVAL = con;
    OUTPUT:
        RETVAL

MODULE = Net::DBus::Binding::Message		PACKAGE = Net::DBus::Binding::Message

PROTOTYPES: ENABLE

DBusMessage *
_create(type)
        IV type;
    PREINIT:
        DBusMessage *msg;
    CODE:
        msg = dbus_message_new(type);
        if (!msg) {
          croak("No memory to allocate message");
        }
        PD_DEBUG("Create msg new %p\n", msg);
        PD_DEBUG("  Type %d\n", dbus_message_get_type(msg));
        RETVAL = msg;
    OUTPUT:
        RETVAL

void
set_no_reply(msg, status)
        DBusMessage *msg;
        dbus_bool_t status;
    CODE:
        dbus_message_set_no_reply(msg, status);



DBusMessageIter *
_iterator_append(msg)
        DBusMessage *msg;
    CODE:
        RETVAL = dbus_new(DBusMessageIter, 1);
        dbus_message_iter_init_append(msg, RETVAL);
    OUTPUT:
        RETVAL


DBusMessageIter *
_iterator(msg)
        DBusMessage *msg;
    CODE:
        RETVAL = dbus_new(DBusMessageIter, 1);
        dbus_message_iter_init(msg, RETVAL);
    OUTPUT:
        RETVAL


MODULE = Net::DBus::Binding::C::Message		PACKAGE = Net::DBus::Binding::C::Message

void
DESTROY(msg)
        DBusMessage *msg;
    CODE:
        PD_DEBUG("De-referencing message %p\n", msg);
        PD_DEBUG("  Type %d\n", dbus_message_get_type(msg));
        PD_DEBUG("  Interface %s\n", dbus_message_get_interface(msg) ? dbus_message_get_interface(msg) : "");
        PD_DEBUG("  Path %s\n", dbus_message_get_path(msg) ? dbus_message_get_path(msg) : "");
        PD_DEBUG("  Member %s\n", dbus_message_get_member(msg) ? dbus_message_get_member(msg) : "");
        dbus_message_unref(msg);

int
dbus_message_get_type(msg)
	DBusMessage *msg;

const char *
dbus_message_get_interface(msg)
	DBusMessage *msg;

const char *
dbus_message_get_path(msg)
	DBusMessage *msg;

const char *
dbus_message_get_destination(msg)
	DBusMessage *msg;

const char *
dbus_message_get_sender(msg)
	DBusMessage *msg;

dbus_uint32_t
dbus_message_get_serial(msg)
	DBusMessage *msg;

const char *
dbus_message_get_member(msg)
	DBusMessage *msg;

void
dbus_message_set_sender(msg, sender);
	DBusMessage *msg;
        const char *sender;

void
dbus_message_set_destination(msg, dest);
	DBusMessage *msg;
        const char *dest;

MODULE = Net::DBus::Binding::Message::Signal		PACKAGE = Net::DBus::Binding::Message::Signal

PROTOTYPES: ENABLE

DBusMessage *
_create(path, interface, name)
        char *path;
        char *interface;
        char *name;
    PREINIT:
        DBusMessage *msg;
    CODE:
        msg = dbus_message_new_signal(path, interface, name);
        if (!msg) {
          croak("No memory to allocate message");
        }
        PD_DEBUG("Create msg new signal %p\n", msg);
        PD_DEBUG("  Type %d\n", dbus_message_get_type(msg));
        PD_DEBUG("  Interface %s\n", dbus_message_get_interface(msg) ? dbus_message_get_interface(msg) : "");
        PD_DEBUG("  Path %s\n", dbus_message_get_path(msg) ? dbus_message_get_path(msg) : "");
        PD_DEBUG("  Member %s\n", dbus_message_get_member(msg) ? dbus_message_get_member(msg) : "");
        RETVAL = msg;
    OUTPUT:
        RETVAL

MODULE = Net::DBus::Binding::Message::MethodCall		PACKAGE = Net::DBus::Binding::Message::MethodCall

PROTOTYPES: ENABLE

DBusMessage *
_create(service, path, interface, method)
        char *service;
        char *path;
        char *interface;
        char *method;
    PREINIT:
        DBusMessage *msg;
    CODE:
        msg = dbus_message_new_method_call(service, path, interface, method);
        if (!msg) {
          croak("No memory to allocate message");
        }
        PD_DEBUG("Create msg new method call %p\n", msg);
        PD_DEBUG("  Type %d\n", dbus_message_get_type(msg));
        PD_DEBUG("  Interface %s\n", dbus_message_get_interface(msg) ? dbus_message_get_interface(msg) : "");
        PD_DEBUG("  Path %s\n", dbus_message_get_path(msg) ? dbus_message_get_path(msg) : "");
        PD_DEBUG("  Member %s\n", dbus_message_get_member(msg) ? dbus_message_get_member(msg) : "");
        RETVAL = msg;
    OUTPUT:
        RETVAL

MODULE = Net::DBus::Binding::Message::MethodReturn		PACKAGE = Net::DBus::Binding::Message::MethodReturn

PROTOTYPES: ENABLE

DBusMessage *
_create(call)
        DBusMessage *call;
    PREINIT:
        DBusMessage *msg;
    CODE:
        msg = dbus_message_new_method_return(call);
        if (!msg) {
          croak("No memory to allocate message");
        }
        dbus_message_set_interface(msg, dbus_message_get_interface(call));
        dbus_message_set_path(msg, dbus_message_get_path(call));
        dbus_message_set_member(msg, dbus_message_get_member(call));
        PD_DEBUG("Create msg new method return %p\n", msg);
        PD_DEBUG("  Type %d\n", dbus_message_get_type(msg));
        PD_DEBUG("  Interface %s\n", dbus_message_get_interface(msg) ? dbus_message_get_interface(msg) : "");
        PD_DEBUG("  Path %s\n", dbus_message_get_path(msg) ? dbus_message_get_path(msg) : "");
        PD_DEBUG("  Member %s\n", dbus_message_get_member(msg) ? dbus_message_get_member(msg) : "");
        RETVAL = msg;
    OUTPUT:
        RETVAL

MODULE = Net::DBus::Binding::Message::Error		PACKAGE = Net::DBus::Binding::Message::Error

PROTOTYPES: ENABLE

DBusMessage *
_create(replyto, name, message)
        DBusMessage *replyto;
        char *name;
        char *message;
    PREINIT:
        DBusMessage *msg;
    CODE:
        msg = dbus_message_new_error(replyto, name, message);
        if (!msg) {
          croak("No memory to allocate message");
        }
        PD_DEBUG("Create msg new error %p\n", msg);
        PD_DEBUG("  Type %d\n", dbus_message_get_type(msg));
        PD_DEBUG("  Interface %s\n", dbus_message_get_interface(msg) ? dbus_message_get_interface(msg) : "");
        PD_DEBUG("  Path %s\n", dbus_message_get_path(msg) ? dbus_message_get_path(msg) : "");
        PD_DEBUG("  Member %s\n", dbus_message_get_member(msg) ? dbus_message_get_member(msg) : "");
        RETVAL = msg;
    OUTPUT:
        RETVAL


MODULE = Net::DBus::Binding::C::Watch			PACKAGE = Net::DBus::Binding::C::Watch

int
get_fileno(watch)
        DBusWatch *watch;
    CODE:
        RETVAL = dbus_watch_get_fd(watch);
    OUTPUT:
        RETVAL

unsigned int
get_flags(watch)
        DBusWatch *watch;
    CODE:
        RETVAL = dbus_watch_get_flags(watch);
    OUTPUT:
        RETVAL

dbus_bool_t
is_enabled(watch)
        DBusWatch *watch;
    CODE:
        RETVAL = dbus_watch_get_enabled(watch);
    OUTPUT:
        RETVAL

void
handle(watch, flags)
        DBusWatch *watch;
        unsigned int flags;
    CODE:
        PD_DEBUG("Handling event %d on fd %d (%p)\n", flags, dbus_watch_get_fd(watch), watch);
        dbus_watch_handle(watch, flags);


void *
get_data(watch)
        DBusWatch *watch;
    CODE:
        RETVAL = dbus_watch_get_data(watch);
    OUTPUT:
        RETVAL

void
set_data(watch, data)
        DBusWatch *watch;
        void *data;
    CODE:
        dbus_watch_set_data(watch, data, NULL);


MODULE = Net::DBus::Binding::C::Timeout			PACKAGE = Net::DBus::Binding::C::Timeout

int
get_interval(timeout)
        DBusTimeout *timeout;
    CODE:
        RETVAL = dbus_timeout_get_interval(timeout);
    OUTPUT:
        RETVAL

dbus_bool_t
is_enabled(timeout)
        DBusTimeout *timeout;
    CODE:
        RETVAL = dbus_timeout_get_enabled(timeout);
    OUTPUT:
        RETVAL

void
handle(timeout)
        DBusTimeout *timeout;
    CODE:
        PD_DEBUG("Handling timeout event %p\n", timeout);
        dbus_timeout_handle(timeout);

void *
get_data(timeout)
        DBusTimeout *timeout;
    CODE:
        RETVAL = dbus_timeout_get_data(timeout);
    OUTPUT:
        RETVAL

void
set_data(timeout, data)
        DBusTimeout *timeout;
        void *data;
    CODE:
        dbus_timeout_set_data(timeout, data, NULL);

MODULE = Net::DBus::Binding::Iterator PACKAGE = Net::DBus::Binding::Iterator

DBusMessageIter *
_recurse(iter)
        DBusMessageIter *iter;
    CODE:
        RETVAL = dbus_new(DBusMessageIter, 1);
        dbus_message_iter_recurse(iter, RETVAL);
    OUTPUT:
        RETVAL

DBusMessageIter *
_open_container(iter, type, sig)
        DBusMessageIter *iter;
        int type;
        char *sig;
    CODE:
        RETVAL = dbus_new(DBusMessageIter, 1);
        dbus_message_iter_open_container(iter, type, sig, RETVAL);
    OUTPUT:
        RETVAL

void
_close_container(iter, sub_iter)
        DBusMessageIter *iter;
        DBusMessageIter *sub_iter;
    CODE:
        dbus_message_iter_close_container(iter, sub_iter);

int
get_arg_type(iter)
        DBusMessageIter *iter;
    CODE:
        RETVAL = dbus_message_iter_get_arg_type(iter);
    OUTPUT:
        RETVAL

int
get_element_type(iter)
        DBusMessageIter *iter;
    CODE:
        RETVAL = dbus_message_iter_get_element_type(iter);
    OUTPUT:
        RETVAL

dbus_bool_t
has_next(iter)
        DBusMessageIter *iter;
    CODE:
	RETVAL = dbus_message_iter_has_next(iter);
    OUTPUT:
        RETVAL

dbus_bool_t
next(iter)
        DBusMessageIter *iter;
    CODE:
        RETVAL = dbus_message_iter_next(iter);
    OUTPUT:
        RETVAL

dbus_bool_t
get_boolean(iter)
        DBusMessageIter *iter;
    CODE:
        dbus_message_iter_get_basic(iter, &RETVAL);
    OUTPUT:
        RETVAL

unsigned char
get_byte(iter)
        DBusMessageIter *iter;
    CODE:
        dbus_message_iter_get_basic(iter, &RETVAL);
    OUTPUT:
        RETVAL

dbus_int32_t
get_int32(iter)
        DBusMessageIter *iter;
    CODE:
        dbus_message_iter_get_basic(iter, &RETVAL);
    OUTPUT:
        RETVAL

dbus_uint32_t
get_uint32(iter)
        DBusMessageIter *iter;
    CODE:
        dbus_message_iter_get_basic(iter, &RETVAL);
    OUTPUT:
        RETVAL

dbus_int64_t
_get_int64(iter)
        DBusMessageIter *iter;
    CODE:
        dbus_message_iter_get_basic(iter, &RETVAL);
    OUTPUT:
        RETVAL

dbus_uint64_t
_get_uint64(iter)
        DBusMessageIter *iter;
    CODE:
        dbus_message_iter_get_basic(iter, &RETVAL);
    OUTPUT:
        RETVAL

double
get_double(iter)
        DBusMessageIter *iter;
    CODE:
        dbus_message_iter_get_basic(iter, &RETVAL);
    OUTPUT:
        RETVAL

char *
get_string(iter)
        DBusMessageIter *iter;
    CODE:
        dbus_message_iter_get_basic(iter, &RETVAL);
    OUTPUT:
        RETVAL


void
append_boolean(iter, val)
        DBusMessageIter *iter;
        dbus_bool_t val;
    CODE:
	if (!dbus_message_iter_append_basic(iter, DBUS_TYPE_BOOLEAN, &val)) {
          croak("cannot append boolean");
        }

void
append_byte(iter, val)
        DBusMessageIter *iter;
        unsigned char val;
    CODE:
	if (!dbus_message_iter_append_basic(iter, DBUS_TYPE_BYTE, &val)) {
          croak("cannot append byte");
        }

void
append_int32(iter, val)
        DBusMessageIter *iter;
        dbus_int32_t val;
    CODE:
	if (!dbus_message_iter_append_basic(iter, DBUS_TYPE_INT32, &val)) {
          croak("cannot append int32");
        }

void
append_uint32(iter, val)
        DBusMessageIter *iter;
        dbus_uint32_t val;
    CODE:
        if (!dbus_message_iter_append_basic(iter, DBUS_TYPE_UINT32, &val)) {
          croak("cannot append uint32");
        }

void
_append_int64(iter, val)
        DBusMessageIter *iter;
        dbus_int64_t val;
    CODE:
        if (!dbus_message_iter_append_basic(iter, DBUS_TYPE_INT64, &val)) {
          croak("cannot append int64");
        }

void
_append_uint64(iter, val)
        DBusMessageIter *iter;
        dbus_uint64_t val;
    CODE:
        if (!dbus_message_iter_append_basic(iter, DBUS_TYPE_UINT64, &val)) {
          croak("cannot append uint64");
        }

void
append_double(iter, val)
        DBusMessageIter *iter;
        double val;
    CODE:
        if (!dbus_message_iter_append_basic(iter, DBUS_TYPE_DOUBLE, &val)) {
          croak("cannot append double");
        }

void
append_string(iter, val)
        DBusMessageIter *iter;
        char *val;
    CODE:
        if (!dbus_message_iter_append_basic(iter, DBUS_TYPE_STRING, &val)) {
          croak("cannot append string");
        }



void
DESTROY(iter)
        DBusMessageIter *iter;
    CODE:
        PD_DEBUG("Destroying iterator %p\n", iter);
        dbus_free(iter);

MODULE = Net::DBus		PACKAGE = Net::DBus
