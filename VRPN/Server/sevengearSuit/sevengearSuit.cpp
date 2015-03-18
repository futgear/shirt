// VRPN Server for sevengearSuit powered by Arduino
// by Sven Schmid
// April 2014

#include <stdio.h>
#include <tchar.h>
#include <string.h>

#include <math.h>

#include "vrpn_Text.h"
#include "vrpn_Analog.h"
#include "vrpn_Serial.h"
#include "vrpn_Button.h"
#include "vrpn_BaseClass.h"             // for ::vrpn_TEXT_ERROR, etc
#include "vrpn_Connection.h"
#include "vrpn_Shared.h"                // for timeval, vrpn_unbuffer, etc
#include "vrpn_MessageMacros.h"         // for VRPN_MSG_INFO, VRPN_MSG_WARNING, VRPN_MSG_ERROR

#include <iostream>
using namespace std;

#undef VERBOSE
// Defines the modes in which the device can find itself.
#define	STATUS_RESETTING	(-1)	// Resetting the device
#define	STATUS_SYNCING		(0)	// Looking for the first character of report
#define	STATUS_READING		(1)	// Looking for the rest of the report
#define MAX_TIME_INTERVAL   (2000000) // max time between reports (usec)

/////////////////////// ANALOG /////////////////////////////

// your analog class must inherin from the vrpn_Analog class
class sevengearSuit : public vrpn_Serial_Analog
{
public:
	sevengearSuit(vrpn_Connection *c,
		const char * port,
		int baud = 38400);
	virtual ~sevengearSuit() {};

	virtual void mainloop();

protected:
	struct timeval _timestamp;
	int _status;					//< Reset, Syncing, or Reading
	int _numchannels;				//< How many analog channels to open

	unsigned _expected_chars;	    //< How many characters to expect in the report
	unsigned char _buffer[256];		//< Buffer of characters in report
	unsigned _bufcount;				//< How many characters we have so far

	struct timeval timestamp;		//< Time of the last report from the device

	virtual int reset(void);		//< Set device back to starting config
	virtual	int get_report(void);		//< Try to read a report from the device

	virtual void clear_values(void);	//< Clears all channels to 0
	
	/// Convert a 24-bit value from a buffer into an unsigned integer value
	vrpn_uint32 convert_24bit_unsigned(const unsigned char *buf);

	/// Convert a 16-bit unsigned value from a buffer into an integer
	vrpn_int32  convert_16bit_unsigned(const unsigned char *buf);

	/// send report whether or not changed
	virtual void report
		(vrpn_uint32 class_of_service = vrpn_CONNECTION_LOW_LATENCY);
};


sevengearSuit::sevengearSuit(vrpn_Connection * c,
	const char * port, int baud) :
	vrpn_Serial_Analog("7GS", c, port, baud, 8, vrpn_SER_PARITY_NONE),
	_numchannels(4)
{
	vrpn_Analog::num_channel = _numchannels;
	// Set the mode to reset
	_status = STATUS_RESETTING;
}


/** Convert a 24-bit value from a buffer into an unsigned integer value.
The value has the most significant byte first in the buffer.
*/

vrpn_uint32 sevengearSuit::convert_24bit_unsigned(const unsigned char *buf)
{
	vrpn_uint32	retval;
	unsigned char bigend_buf[4];
	const unsigned char *bufptr = bigend_buf;

	// Store the three values into three bytes of a big-endian 32-bit integer
	bigend_buf[0] = 0;
	bigend_buf[1] = buf[0];
	bigend_buf[2] = buf[1];
	bigend_buf[3] = buf[2];

	// Convert the value to an integer
	vrpn_unbuffer((const char **)&bufptr, &retval);
	return retval;
}


/** Convert a 16-bit unsigned value from a buffer into an integer value.
The value has the most significant byte first in the buffer.
*/

vrpn_int32 sevengearSuit::convert_16bit_unsigned(const unsigned char *buf)
{
	vrpn_int32	retval;
	unsigned char bigend_buf[4];
	const unsigned char *bufptr = bigend_buf;

	// Store the values into two bytes of a big-endian 32-bit integer
	bigend_buf[0] = 0;
	bigend_buf[1] = 0;
	bigend_buf[2] = buf[0];
	bigend_buf[3] = buf[1];

	// Convert the value to an integer
	vrpn_unbuffer((const char **)&bufptr, &retval);
	return retval;
}

int	sevengearSuit::reset(void)
{
	unsigned char	command[128];

	// Give it a reasonable amount of time to finish (2 seconds), then timeout
	vrpn_flush_input_buffer(serial_fd);
	sprintf((char *)command, "%c%c%c", 0xa4, 0xff, 0x02);
	// We're now waiting for a response from the box
	status = STATUS_SYNCING;

	VRPN_MSG_WARNING("reset complete (this is good)");

	vrpn_gettimeofday(&timestamp, NULL);	// Set watchdog now
	return 0;
}

void	sevengearSuit::clear_values(void)
{
	int	i;

	for (i = 0; i < _numchannels; i++) {
		vrpn_Analog::channel[i] = vrpn_Analog::last[i] = 0;
	}
}



//   This function will read characters until it has a full report, then
// put that report into analog fields and call the report methods on these.
//   The time stored is that of the first character received as part of the
// report.
//   Reports start with different characters, and the length of the report
// depends on what the first character of the report is.  We switch based
// on the first character of the report to see how many more to expect and
// to see how to handle the report.
int sevengearSuit::get_report(void)
{
	int ret;		// Return value from function call to be checked
	char errmsg[256];

	//--------------------------------------------------------------------
	// If we're SYNCing, then the next character we get should be the start
	// of a report.  If we recognize it, go into READing mode and tell how
	// many characters we expect total. If we don't recognize it, then we
	// must have misinterpreted a command or something; reset the Magellan
	// and start over
	//--------------------------------------------------------------------

	if (status == STATUS_SYNCING) {
		// Try to get a character.  If none, just return.
		if (vrpn_read_available_characters(serial_fd, _buffer, 1) != 1) {
			return 0;
		}

		switch (_buffer[0]) {
			case 0xa0:
				_expected_chars = 85; status = STATUS_READING; break;

			default:
				// Not a recognized command, keep looking
				return 0;
		}


		// Got the first character of a report -- go into READING mode
		// and record that we got one character at this time. The next
		// bit of code will attempt to read the rest of the report.
		// The time stored here is as close as possible to when the
		// report was generated.
		_bufcount = 1;
		vrpn_gettimeofday(&timestamp, NULL);
		status = STATUS_READING;
#ifdef	VERBOSE
		printf("... Got the 1st char: %d \n", _buffer[0]);
#endif
	}

	//--------------------------------------------------------------------
	// Read as many bytes of this report as we can, storing them
	// in the buffer.  We keep track of how many have been read so far
	// and only try to read the rest.
	//--------------------------------------------------------------------

	ret = vrpn_read_available_characters(serial_fd, &_buffer[_bufcount],
		_expected_chars - _bufcount);
	if (ret == -1) {
		VRPN_MSG_ERROR("Error reading");
		status = STATUS_RESETTING;
		return 0;
	}
	_bufcount += ret;
#ifdef	VERBOSE
	if (ret != 0) printf("... got %d characters (%d total)\n", ret, _bufcount);
#endif
	if (_bufcount < _expected_chars) {	// Not done -- go back for more
		return 0;
	}

#ifdef	VERBOSE
	printf("got a complete report (%d of %d)!\n", _bufcount, _expected_chars);
#endif

	//--------------------------------------------------------------------
	// Decode the report and store the values in it into the analog values
	// if appropriate.
	//	#TEMP
	//	#DEL
	//	#ACC_x, ACC_y, ACC_z
	//	#GYRO_x, GYRO_y, GYRO_z
	//	#FILTERED_x, FILTERED_y, FILTERED_z
	//	#ADC0, ..., ADC31
	//--------------------------------------------------------------------
	switch (_buffer[0]) {
	case 0xa0:	// Shirt only
		vrpn_Analog::num_channel = 43;
		// TEMP
		channel[0] = convert_16bit_unsigned(&_buffer[1]);
		// DEL
		channel[1] = convert_16bit_unsigned(&_buffer[3]);
		// ACCELERATOR
		channel[2] = convert_16bit_unsigned(&_buffer[5]);
		channel[3] = convert_16bit_unsigned(&_buffer[7]);
		channel[4] = convert_16bit_unsigned(&_buffer[9]);
		// GYRO
		channel[5] = convert_16bit_unsigned(&_buffer[11]);
		channel[6] = convert_16bit_unsigned(&_buffer[13]);
		channel[7] = convert_16bit_unsigned(&_buffer[15]);
		// FILTERED
		channel[8] = convert_16bit_unsigned(&_buffer[17]);
		channel[9] = convert_16bit_unsigned(&_buffer[19]);
		channel[10] = convert_16bit_unsigned(&_buffer[21]);
		// ADCs
		channel[11] = convert_16bit_unsigned(&_buffer[23]); // A0
		channel[12] = convert_16bit_unsigned(&_buffer[25]); // A1
		channel[13] = convert_16bit_unsigned(&_buffer[27]); // A2
		channel[14] = convert_16bit_unsigned(&_buffer[29]); // A3
		channel[15] = convert_16bit_unsigned(&_buffer[31]); // A4
		channel[16] = convert_16bit_unsigned(&_buffer[33]); // A5
		channel[17] = convert_16bit_unsigned(&_buffer[35]); // A6
		channel[18] = convert_16bit_unsigned(&_buffer[37]); // A7

		channel[19] = convert_16bit_unsigned(&_buffer[39]); // B0
		channel[20] = convert_16bit_unsigned(&_buffer[41]); // B1
		channel[21] = convert_16bit_unsigned(&_buffer[43]); // B2
		channel[22] = convert_16bit_unsigned(&_buffer[45]); // B3
		channel[23] = convert_16bit_unsigned(&_buffer[47]); // B4
		channel[24] = convert_16bit_unsigned(&_buffer[49]); // B5
		channel[25] = convert_16bit_unsigned(&_buffer[51]); // B6
		channel[26] = convert_16bit_unsigned(&_buffer[53]); // B7

		channel[27] = convert_16bit_unsigned(&_buffer[55]); // C0
		channel[28] = convert_16bit_unsigned(&_buffer[57]); // C1
		channel[29] = convert_16bit_unsigned(&_buffer[59]); // C2
		channel[30] = convert_16bit_unsigned(&_buffer[61]); // C3
		channel[31] = convert_16bit_unsigned(&_buffer[63]); // C4
		channel[32] = convert_16bit_unsigned(&_buffer[65]); // C5
		channel[33] = convert_16bit_unsigned(&_buffer[67]); // C6
		channel[34] = convert_16bit_unsigned(&_buffer[69]); // C7

		channel[35] = convert_16bit_unsigned(&_buffer[71]); // D0
		channel[36] = convert_16bit_unsigned(&_buffer[73]); // D1
		channel[37] = convert_16bit_unsigned(&_buffer[75]); // D2
		channel[38] = convert_16bit_unsigned(&_buffer[77]); // D3
		channel[39] = convert_16bit_unsigned(&_buffer[79]); // D4
		channel[40] = convert_16bit_unsigned(&_buffer[81]); // D5
		channel[41] = convert_16bit_unsigned(&_buffer[83]); // D6
		channel[42] = convert_16bit_unsigned(&_buffer[85]); // D7
		break;

	default:
		sprintf(errmsg, "sevengearSuit: Unhandled command (0x%02x), resetting\n", _buffer[0]);
		VRPN_MSG_ERROR(errmsg);
		status = STATUS_RESETTING;
		return 0;
	}

	//--------------------------------------------------------------------
	// Done with the decoding, send the reports and go back to syncing
	//--------------------------------------------------------------------

	report();	// Report, rather than report_changes(), since it is an absolute device
	status = STATUS_SYNCING;
	_bufcount = 0;

	return 1;
}



void	sevengearSuit::report(vrpn_uint32 class_of_service)
{
	vrpn_Analog::timestamp = timestamp;

	vrpn_Analog::report(class_of_service);
}




void	sevengearSuit::mainloop()
{
	char errmsg[256];

	vrpn_gettimeofday(&_timestamp, NULL);
	vrpn_Analog::timestamp = _timestamp;

	server_mainloop();

	switch (status) {
	case STATUS_RESETTING:
		reset();
		break;

	case STATUS_SYNCING:
	case STATUS_READING:
		{
			// It turns out to be important to get the report before checking
			// to see if it has been too long since the last report.  This is
			// because there is the possibility that some other device running
			// in the same server may have taken a long time on its last pass
			// through mainloop().  Trackers that are resetting do this.  When
			// this happens, you can get an infinite loop -- where one tracker
			// resets and causes the other to timeout, and then it returns the
			// favor.  By checking for the report here, we reset the timestamp
			// if there is a report ready (ie, if THIS device is still operating).
			while (get_report()) {};	// Keep getting reports so long as there are more

			struct timeval current_time;
			vrpn_gettimeofday(&current_time, NULL);
			if (vrpn_TimevalDuration(current_time, timestamp) > MAX_TIME_INTERVAL) {
				sprintf(errmsg, "Timeout... current_time=%ld:%ld, timestamp=%ld:%ld",
					current_time.tv_sec, static_cast<long>(current_time.tv_usec),
					timestamp.tv_sec, static_cast<long>(timestamp.tv_usec));
				VRPN_MSG_ERROR(errmsg);
				status = STATUS_RESETTING;
			}
		}
		break;

	default:
		VRPN_MSG_ERROR("Unknown mode (internal error)");
		break;
	}
}

/////////////////////// BUTTON /////////////////////////////

// your button class must inherit from the vrpn_Button class
class myButton : public vrpn_Button
{
public:
	myButton( vrpn_Connection *c = 0 );
	virtual ~myButton() {};

	virtual void mainloop();

protected:
	struct timeval _timestamp;
};


myButton::myButton( vrpn_Connection *c /*= 0 */ ) :
	vrpn_Button( "Button0", c )
{
	// Setting the number of buttons to 10
	vrpn_Button::num_buttons = 10;

	vrpn_uint32 i;

	// initializing all buttons to false
	for (i = 0; i < (vrpn_uint32)vrpn_Button::num_buttons; i++) {
		vrpn_Button::buttons[i] = vrpn_Button::lastbuttons[i] = 0;
	}
}

void
myButton::mainloop()
{
	vrpn_gettimeofday(&_timestamp, NULL);
	vrpn_Button::timestamp = _timestamp;

	// forcing values to change otherwise vrpn doesn't report the changes
	static int b=0; b++;

	for( unsigned int  i=0; i<vrpn_Button::num_buttons;i++)
	{
		// XXX Set your values here !
		buttons[i] = (i+b)%2;
	}

	// Send any changes out over the connection.
	vrpn_Button::report_changes();

	server_mainloop();
}


int _tmain(int argc, _TCHAR* argv[])
{
	// Creating the network server
	vrpn_Connection_IP* m_Connection = new vrpn_Connection_IP();

	// Creating the tracker
	sevengearSuit*  serverAnalog  = new sevengearSuit(m_Connection,"COM7", 38400 );
	myButton*  serverButton  = new myButton(m_Connection );

	cout << "Created VRPN server." << endl;

	while(true)
	{
		serverAnalog->mainloop();
		serverButton->mainloop();

		m_Connection->mainloop();

		// Calling Sleep to let the CPU breathe.
		SleepEx(1,FALSE);
	}
}

