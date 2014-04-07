#include "vrpn_Analog.h"

#include <iostream>
using namespace std;

void VRPN_CALLBACK handle_analog( void* userData, const vrpn_ANALOGCB a )
{
	int nbChannels = a.num_channel;

	cout << "SevenGear Suit : ";

	for( int i=0; i < a.num_channel; i++ )
	{
		cout << i << ": " << a.channel[i] << " ";
	}

	cout << endl;
}


int main(int argc, char* argv[])
{
	vrpn_Analog_Remote* vrpnAnalog = new vrpn_Analog_Remote("7GS@localhost");

	vrpnAnalog->register_change_handler( 0, handle_analog );

	while(1)
	{
		vrpnAnalog->mainloop();
	}

	return 0;
}

