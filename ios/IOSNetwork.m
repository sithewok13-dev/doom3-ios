/*
 * Multiplayer on the same Wi-Fi: how phones find each other's games.
 *
 * DOOM 3 finds the games on its network by broadcasting a question to every
 * machine on it; iOS doesn't let an app broadcast (that takes a capability
 * Apple must grant). So each game served from here is also advertised with
 * Bonjour (as _doom3._udp, on the server's port), and the multiplayer menu's
 * list of games asks each game Bonjour finds, directly, as well as
 * broadcasting (sys/ios/ios_net.h, framework/async/). Asking directly needs
 * only the Local Network permission iOS asks the player for, the first
 * time.
 *
 * Uses the system's DNS-SD (dns_sd.h); everything runs on the main queue,
 * which SDL's event pumping keeps going.
 *
 * Compiled with ARC.
 */

#import <Foundation/Foundation.h>
#include <dns_sd.h>
#include <arpa/inet.h>
#include <netinet/in.h>

#include "sys/ios/ios_net.h"

#define IOSNET_SERVICE "_doom3._udp"
#define IOSNET_MAX_SERVERS 32

// the game served from here, advertised
static DNSServiceRef iosNet_registerRef = NULL;

// the games found: "a.b.c.d:port", and how many of them the engine hasn't
// been told of yet
static DNSServiceRef iosNet_browseRef = NULL;
static char iosNet_aServers[IOSNET_MAX_SERVERS][32];
static int iosNet_numServers = 0;
static int iosNet_numTold = 0;

static void iosNet_Registered(DNSServiceRef ref, DNSServiceFlags flags, DNSServiceErrorType err,
							  const char* name, const char* type, const char* domain, void* context)
{
	if (err != kDNSServiceErr_NoError) NSLog(@"DOOM 3: Bonjour couldn't advertise the game (%d)", err);
}

void IOSNet_Advertise(int port, const char* name)
{
	if (iosNet_registerRef) {
		DNSServiceRefDeallocate(iosNet_registerRef);
		iosNet_registerRef = NULL;
	}
	if (port <= 0) return;
	// (a name too long, or none: the device's own)
	const char* serviceName = (name && name[0] && strlen(name) < 63) ? name : NULL;
	DNSServiceErrorType err = DNSServiceRegister(&iosNet_registerRef, 0, kDNSServiceInterfaceIndexAny, serviceName,
												 IOSNET_SERVICE, NULL, NULL, htons((uint16_t)port), 0, NULL,
												 iosNet_Registered, NULL);
	if (err != kDNSServiceErr_NoError) {
		iosNet_registerRef = NULL;
		return;
	}
	DNSServiceSetDispatchQueue(iosNet_registerRef, dispatch_get_main_queue());
}

// A game's address found (resolve, then its IPv4 address): kept, once
static void iosNet_AddServer(const char* address)
{
	for (int i = 0; i < iosNet_numServers; i++) {
		if (strcmp(iosNet_aServers[i], address) == 0) return;
	}
	if (iosNet_numServers >= IOSNET_MAX_SERVERS) return;
	strlcpy(iosNet_aServers[iosNet_numServers++], address, sizeof(iosNet_aServers[0]));
}

static void iosNet_GotAddress(DNSServiceRef ref, DNSServiceFlags flags, uint32_t iface, DNSServiceErrorType err,
							  const char* host, const struct sockaddr* addr, uint32_t ttl, void* context)
{
	if (err == kDNSServiceErr_NoError && addr && addr->sa_family == AF_INET) {
		char ip[INET_ADDRSTRLEN];
		const struct sockaddr_in* in = (const struct sockaddr_in*)addr;
		if (inet_ntop(AF_INET, &in->sin_addr, ip, sizeof(ip))) {
			char address[32];
			snprintf(address, sizeof(address), "%s:%d", ip, (int)(intptr_t)context);
			iosNet_AddServer(address);
		}
	}
	if (!(flags & kDNSServiceFlagsMoreComing)) DNSServiceRefDeallocate(ref);
}

static void iosNet_Resolved(DNSServiceRef ref, DNSServiceFlags flags, uint32_t iface, DNSServiceErrorType err,
							const char* fullName, const char* host, uint16_t port, uint16_t txtLen,
							const unsigned char* txt, void* context)
{
	if (err == kDNSServiceErr_NoError) {
		DNSServiceRef addrRef = NULL;
		if (DNSServiceGetAddrInfo(&addrRef, 0, iface, kDNSServiceProtocol_IPv4, host, iosNet_GotAddress,
								  (void*)(intptr_t)ntohs(port)) == kDNSServiceErr_NoError) {
			DNSServiceSetDispatchQueue(addrRef, dispatch_get_main_queue());
		}
	}
	DNSServiceRefDeallocate(ref);
}

static void iosNet_Browsed(DNSServiceRef ref, DNSServiceFlags flags, uint32_t iface, DNSServiceErrorType err,
						   const char* name, const char* type, const char* domain, void* context)
{
	if (err != kDNSServiceErr_NoError || !(flags & kDNSServiceFlagsAdd)) return;
	DNSServiceRef resolveRef = NULL;
	if (DNSServiceResolve(&resolveRef, 0, iface, name, type, domain, iosNet_Resolved, NULL) == kDNSServiceErr_NoError) {
		DNSServiceSetDispatchQueue(resolveRef, dispatch_get_main_queue());
	}
}

void IOSNet_Browse(void)
{
	if (iosNet_browseRef) return;
	if (DNSServiceBrowse(&iosNet_browseRef, 0, kDNSServiceInterfaceIndexAny, IOSNET_SERVICE, NULL,
						 iosNet_Browsed, NULL) != kDNSServiceErr_NoError) {
		iosNet_browseRef = NULL;
		return;
	}
	DNSServiceSetDispatchQueue(iosNet_browseRef, dispatch_get_main_queue());
}

int IOSNet_Servers(char addresses[][32], int max, int onlyNew)
{
	int first = onlyNew ? iosNet_numTold : 0;
	int n = 0;
	for (int i = first; i < iosNet_numServers && n < max; i++) {
		strlcpy(addresses[n++], iosNet_aServers[i], 32);
	}
	iosNet_numTold = iosNet_numServers;
	return n;
}
