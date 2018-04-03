#include <k-hud>
#include <smlib>

#define MAXCOLORS 156
#define SPECMODE_FIRSTPERSON 			4
#define SPECMODE_3RDPERSON 				5

//Jamie put shit into here
char HtmlColorCodes[MAXCOLORS+1][16] = {"ff0000", "ff0600", "ff0c00", "ff1100", "ff1700", "ff1d00", "ff2300", "ff2800", "ff2e00", "ff3400", "ff3a00", "ff4000", "ff4500", "ff4b00", "ff5100", \
"ff5700", "ff5c00", "ff6200", "ff6800", "ff6e00", "ff7300", "ff7900", "ff7f00", "ff8500", "ff8a00", "ff9000", "ff9500", "ff9b00", "ffa000", "ffa600", "ffac00", "ffb100", "ffb700", "ffbc00", \
"ffc200", "ffc700", "ffcd00", "ffd200", "ffd800", "ffde00", "ffe300", "ffe900", "ffee00", "fff400", "fff900", "ffff00", "f3ff00", "e8ff00", "dcff00", "d1ff00", "c5ff00", "b9ff00", "aeff00", \
"a2ff00", "97ff00", "8bff00", "7fff00", "74ff00", "68ff00", "5dff00", "51ff00", "46ff00", "3aff00", "2eff00", "23ff00", "17ff00", "0cff00", "00ff00", "00ff0c", "00ff17", "00ff23", "00ff2e", "00ff3a", \
"00ff46", "00ff51", "00ff5d", "00ff68", "00ff74", "00ff80", "00ff8b", "00ff97", "00ffa2", "00ffae", "00ffb9", "00ffc5", "00ffd1", "00ffdc", "00ffe8", "00fff3", "00ffff", "00f3ff", "00e8ff", "00dcff", \
"00d1ff", "00c5ff", "00b9ff", "00aeff", "00a2ff", "0097ff", "008bff", "007fff", "0074ff", "0068ff", "005dff", "0051ff", "0046ff", "003aff", "002eff", "0023ff", "0017ff", "000cff", "0000ff", "0600ff", \
"0c00ff", "1200ff", "1800ff", "1e00ff", "2400ff", "2a00ff", "3000ff", "3600ff", "3c00ff", "4200ff", "4900ff", "4f00ff", "5500ff", "5b00ff", "6100ff", "6700ff", "6d00ff", "7300ff", "7900ff", "7f00ff", \
"8500ff", "8b00ff", "9000f3", "9600e8", "9b00dc", "a000d1", "a500c5", "ab00b9", "b000ae", "b500a2", "ba0097", "c0008b", "c5007f", "ca0074", "d00068", "d5005d", "da0051", "df0046", "e5003a", "ea002e", \
"ef0023", "f40017", "fa000c", "ff0000"};

int currentColor = 0;

public void OnPluginStart()
{
	//K_AddHud(MakeHud, "Simple hud", 999, true);
	CreateTimer(0.1, Timer_UpdateColors, _, TIMER_REPEAT);
}

public void K_LoadPluginHud()
{
	K_AddHud(MakeHud, "Simple hud", 2, false);
}

public Action Timer_UpdateColors(Handle timer)
{
	if(currentColor == MAXCOLORS)
		currentColor = 0;
	else
		++currentColor;

}

public void MakeHud(int client, char[] PrintText, int maxSize)
{
	char centerText[256];
	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity); //velocity
	float currentspeed = SquareRoot(Pow(fVelocity[0],2.0)+Pow(fVelocity[1],2.0)); //player speed (units per secound)
	
	char cSpeed[32];

	if(currentspeed < 240)
		Format(cSpeed, sizeof(cSpeed), "FFFFAA");
	else if(currentspeed < 300)
		Format(cSpeed, sizeof(cSpeed), "FFFF88");
	else if(currentspeed < 500)
		Format(cSpeed, sizeof(cSpeed), "FFFF66");
	else if(currentspeed < 700)
		Format(cSpeed, sizeof(cSpeed), "FFFF44");
	else if(currentspeed < 900)
		Format(cSpeed, sizeof(cSpeed), "FFFF22");
	else if(currentspeed < 1200)
		Format(cSpeed, sizeof(cSpeed), "FFCC11");
	else if(currentspeed < 1500)
		Format(cSpeed, sizeof(cSpeed), "FFBB00");
	else if(currentspeed < 2200)
		Format(cSpeed, sizeof(cSpeed), "FF8800");
	else
		Format(cSpeed, sizeof(cSpeed), "FF0000");

	Format(centerText, sizeof(centerText), "Speed: <font color='#%s'>%d</font>", cSpeed, RoundToFloor(currentspeed));
	Format(centerText, sizeof(centerText), "%s\nPlayer: <font color='#%s'>%N</font>", centerText, HtmlColorCodes[currentColor], client);
	FormatShowKeys(Client_GetButtons(client), centerText, sizeof(centerText));
	FormatEx(PrintText, maxSize, "<font face='aerial'><font size='16'>%s</font></font>", centerText);
}


public void FormatShowKeys(int iButtons, char[] input, int maxsize)
{
	char []sOutput = new char[maxsize];
	
	// Is he pressing "w"?
	if(iButtons & IN_FORWARD)
		Format(sOutput, maxsize, "\n      W\n");
	else
		Format(sOutput, maxsize, "\n      -\n");
	
	// Is he pressing "a"?
	if(iButtons & IN_MOVELEFT)
		Format(sOutput, maxsize, "%s  A ", sOutput);
	else
		Format(sOutput, maxsize, "%s  - ", sOutput);
		
	// Is he pressing "s"?
	if(iButtons & IN_BACK)
		Format(sOutput, maxsize, "%s  S ", sOutput);
	else
		Format(sOutput, maxsize, "%s  - ", sOutput);
		
	// Is he pressing "d"?
	if(iButtons & IN_MOVERIGHT)
		Format(sOutput, maxsize, "%s  D \n", sOutput);
	else
		Format(sOutput, maxsize, "%s  - \n", sOutput);
		
	// Is he pressing "ctrl"?
	if(iButtons & IN_DUCK)
		Format(sOutput, maxsize, "%s      DUCK", sOutput);
	else
		Format(sOutput, maxsize, "%s      -", sOutput);
	
	// Is he pressing "space"?
	//if(g_bDisplayJump[client])
	if(iButtons & IN_JUMP)
		Format(sOutput, maxsize, "%s JUMP", sOutput);
	else
		Format(sOutput, maxsize, "%s -", sOutput);
	Format(input, maxsize, "%s%s", input, sOutput);
}