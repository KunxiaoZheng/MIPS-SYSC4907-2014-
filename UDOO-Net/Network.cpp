//============================================================================
// Name        : SocketModule.cpp
// Author      : Andrew Fleck
// Version     : 1.0.0
// Copyright   : Your copyright notice
// Description : Network Code for UDOO
//============================================================================

#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <thread>
#include "SocketModule.h"

using namespace std;

bool do_server() {
	bool running = true;

	SocketModule* server= new SocketModule;
	server->createserver(12345);
	std::cout<<"createdserver";

	while (running){
		server->receivemsg();
		server->sendmsg("received msg");
	}
	return 1;
}

bool do_client(){
	SocketModule* client = new SocketModule;
	client->connectclient("127.0.0.1", 12345);
	std::cout<<"connectedclient";
	bool running = true;
	while(running){
	client->sendmsg("heyshitlords");
	}
	return 1;
}

int main(void) {
	//creating SocketModule pointers to reserved memory on heap
	//SocketModule * serversocket = new SocketModule();
	//SocketModule * clientsocket = new SocketModule();

	//SocketModule &ss_pointer = *serversocket;
	//SocketModule &cs_pointer = *clientsocket;

	//std::thread sthread (do_server,ss_pointer);
	//std::thread cthread (do_client,cs_pointer);

	std::thread sthread (do_server);
	std::thread cthread (do_client);
	sthread.join();
	cthread.join();

	//delete serversocket;
	//delete clientsocket;

	//do_server();
	return EXIT_SUCCESS;
}


