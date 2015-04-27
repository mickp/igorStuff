from Tkinter import *
import tkFileDialog
import u6
from time import sleep
from datetime import datetime
import os
import re

###Constants for the LabJack U6
#maximum acquisiton time
MAX_TIME=12
#target frequency
FREQ=4096.0
#LabJack gains
GAINS={
    '10V':{'gain':1,'bits':0, 'maxV':10.1, 'minV':-10.6},
    '1V':{'gain':10,'bits':1<<3, 'maxV':1.01, 'minV':-1.06},
    '100mV':{'gain':100,'bits':2<<3, 'maxV':0.101, 'minV':-0.106},
    '10mV':{'gain':1000,'bits':3<<3, 'maxV':0.0101, 'minV':-0.0106}
    }
DIFFERENTIAL = 1<<7
#channels to acquire
CHANNELS=[0]#[0,2]#[0,1,2] #[0,1,4]

###Contants for the VA-2
#Hash to stores the three gains for the three functions
VAGAINS={
    'ACCEL':{'1':1, '2':1e-1, '3':1e-2},
    'VEL':{'1':1e-2, '2':1e-3, '3':1e-4},
    'DISP':{'1':100e-6, '2':10e-6, '3':1e-6}
    }

###Other constants
FNEXT = '.txt'
FNDIGITS = 4
COLOURS=['white', 'cyan', 'yellow', 'green', 'magenta', 'red', 'gray', 'blue', 'crimson']

###Our application
class App:
    def __init__(self, master):
        ###Set up the UI
        #Initialise variables
        self.master = master
        self.path = StringVar()
        self.basename = StringVar(value='data')
        self.gain = StringVar()
        self.gain.set('3')
        self.func = StringVar()
        self.func.set("ACCEL")
        self.range = StringVar()
        self.range.set('1V')
        self.headers = []
        self.output = []
        self.autoLimit = StringVar(value='10')            

        #Path and filename controls
        frame = Frame(master, border=2)
        frame.pack()

        b_path = Button(frame, text="Path...", command=self.set_path)
        b_path.grid(row=1, column=1, sticky=E)

        e_path = Entry(frame, width=40,
                       justify=LEFT, relief=SUNKEN,
                       textvariable=self.path,
                       state=DISABLED)
        e_path.grid(row=1, column=2, columnspan=7, sticky=EW, padx=2)

        l_basename = Label(frame,
                           text='Basename')
        l_basename.grid(row=2, column=1, sticky=E)
        
        e_basename = Entry(frame, width=40,
                           justify=LEFT, relief=SUNKEN,
                           textvariable=self.basename)
        e_basename.grid(row=2, column=2, columnspan=7, sticky=EW, padx=2)

        #Function menu
        l_func = Label(frame, text="Function")
        o_func = OptionMenu(frame, self.func, "ACCEL", "VEL", "DISP")
        o_func.config(width=4)

        #Gain menu
        l_gain = Label(frame, text="Gain")
        o_gain = OptionMenu(frame, self.gain, "1", "2", "3")
        o_gain.config(width=1)

        #Range menu
        l_range = Label(frame, text="Range")
        o_range = apply(OptionMenu, (frame, self.range) + tuple(t[0] for t in sorted(GAINS.iteritems(), key=lambda x: x[1]['gain'])))
        o_range.config(width=5)

        l_func.grid(row=3,column=1, sticky=E)
        o_func.grid(row=3,column=2, sticky=W)
        Label(frame, text="  ").grid(row=3,column=3)
        l_gain.grid(row=3,column=4, sticky=E)
        o_gain.grid(row=3,column=5, sticky=W)
        Label(frame, text="  ").grid(row=3,column=6)
        l_range.grid(row=3,column=7, sticky=E)
        o_range.grid(row=3,column=8, sticky=W)

        #Acquire, save and quit buttons.
        buttonFrame = Frame(frame, pady=8)
        buttonFrame.grid(row=4, column=1, columnspan=8, sticky=E)
        b_quit = Button(buttonFrame, text="Quit", command=frame.quit)
        b_quit.pack(side=RIGHT, padx=2)

        Label(buttonFrame, text="   ").pack(side=RIGHT)

        vcmd = (self.master.register(self.validateInt), '%s', '%P')

        self.e_autoLimit = Entry(buttonFrame, width=3, validate='key', validatecommand=vcmd, textvariable=self.autoLimit)    
        self.e_autoLimit.pack(side=RIGHT, padx=2)

        self.b_autogo = StatefulButton(buttonFrame, text="Acq & save", command=self.autogo, state=DISABLED)
        self.b_autogo.pack(side=RIGHT, padx=2)

        Label(buttonFrame, text="   ").pack(side=RIGHT)

        self.b_save = StatefulButton(buttonFrame, text="Save", command=self.save)
        self.b_save.pack(side=RIGHT, padx=2)
        self.b_save.disable()

        self.b_go = StatefulButton(buttonFrame, text="Acquire", command=self.acquire)
        self.b_go.pack(side=RIGHT, padx=2)

        statusframe = Frame(master)
        statusframe.pack(side=BOTTOM, fill=X)

        self.status = StatusBar(statusframe)
        self.status.pack(side=BOTTOM, fill=X)

        plotframe = Frame(master, width=640, heigh=480)
        plotframe.pack(fill=X)
        self.plot = SimplePlot(plotframe, bg="black")
        self.plot.pack(fill=X)

    def validateInt(self, s, P):
        try:
            int('0' + P)
        except:
            return False

        if len(P) > 3:
            return False
        else:
            return True
        

    def autogo(self):
        i = 0
        while (i < int('0' + self.autoLimit.get())):
            self.acquire()
            self.save()
            i += 1

    def set_status(self, s):
        #Sets the text in the status bar
        self.status.set(s)

    def set_path(self):
        #Open a file dialog to ask for a path.
        path = tkFileDialog.askdirectory(
            title="Choose a target folder. To create a new folder, select a parent folder then type a name in the box below.",
            mustexist=False,
            initialdir=self.path.get())
        if len(path) > 0:
            #If a path is chosen...
            #...display it...
            self.path.set(path)
            #...update the status bar...
            self.status.set('Ready.')
            #...enable the autogo button...
            self.b_autogo.enable()
            #...enable the save button if there is data
            if len(self.output) > 0:
                self.b_save.enable()
                
    def save(self):
        #Make sure target path exists
        self.set_status('Opening file for output.')
        fileBase = self.basename.get()
        try:
            if not os.path.exists(app.path.get()):
                os.makedirs(app.path.get())                  
        except:
             self.set_status('Could not open path to save data. Check path.')
             raise

        #Open file
        try:
            allFiles = os.listdir(app.path.get())
            matchFiles = filter(
                lambda x:
                re.match(fileBase + '[0-9]{'+ str(FNDIGITS) + '}' + FNEXT, x, re.IGNORECASE), allFiles)
            matchFiles.sort(reverse=True)
            if len(matchFiles) > 0:
                fileNum = str(int(matchFiles[0].lower().lstrip(fileBase.lower()).rstrip(FNEXT.lower())) + 1).zfill(FNDIGITS)
            else:
                fileNum = str(0).zfill(FNDIGITS)

            filePath = os.path.realpath(os.path.join(self.path.get(),fileBase + fileNum + FNEXT))

            f = open(filePath, 'w')
        except:
            self.set_status('There was a problem opening a file to write to. Check path.')
            raise

        try:
            for label, value in self.headers:
                f.write(label + ': ' + str(value) + '\n')

            f.write('BEGIN\n')
            for row in self.output:
                for col in row:
                    f.write(str(col) + '\t')
                f.write('\r')
            f.write('END') 

        
            #Close the output file
            f.close()
        
            #Disable save button to prevent saving multiple copies
            self.b_save.disable()

        except:
            try:
                os.remove(filepath)
            except:
                pass
            self.set_status('There was a problem writing to the file.')
            raise

        self.set_status('Data saved to ' + os.path.basename(f.name) + '. Ready.')


    def acquire(self):
        #Disable go button
        self.b_go.disable()
        self.b_save.disable()
        self.output=[]
        self.headers=[]
        self.master.config(cursor="wait")

        #Connect to U6
        self.set_status('Connecting to U6 device.')
        try:
            lj = CaptureDevice()
            lj.connect()
        except:
            self.set_status('Could not open connection to LabJack U6.')
            self.master.config(cursor="")
            self.b_go.enable()
            raise
    
        #Acquire data
        self.set_status('Acquiring data.')
        try:
            gainIndex = GAINS[self.range.get()]['bits']
            lj.acquire(gainIndex)
            lj.close()
        except:
            self.set_status('There was a problem during data acquisition.')
            self.master.config(cursor="")
            self.b_go.enable()
            raise        

        #output = [lj.ain0, lj.ain1, lj.ain2]
        #output = zip(*output)
        #self.output=zip(lj.ain0, lj.ain1, lj.ain2)
        self.output = zip(*lj.output)

        headerLabels = ['TIME','FREQ','FUNC','GAIN']
        headerValues = [lj.start, FREQ,
                        self.func.get(),
                        VAGAINS[self.func.get()][self.gain.get()]
                        ]

        self.headers = zip(headerLabels, headerValues)

        self.plot.delete("all")
        self.plot.setscale(0, len(lj.output[0])/FREQ, 1.02 * GAINS[self.range.get()]['minV'], 1.02 * GAINS[self.range.get()]['maxV'])
        for trace, colour in map(None, lj.output, COLOURS):
            t = 0
            if trace is not None:
                for y in trace:
                    self.plot.plot(t, y, colour)
                    t += lj.dt
        self.plot.update()
        self.set_status('Data acquired.')
        self.master.config(cursor="")
        self.b_go.enable()

        if len(self.path.get()) == 0:
            self.set_status('Data acquired. Set path to save data.')
        else:
            self.b_save.enable()


class CaptureDevice():
    def __init__(self):
        self.d = None
        self.missed = None
        self.start = None
        self.stop = None
        self.dt = None
        self.output = []
        #self.ain0 = []
        #self.ain1 = []
        #self.ain2 = []

    def connect(self):
        self.d = u6.U6()
        self.d.getCalibrationData()

    def close(self):
        self.d.close()

    def acquire(self, gainIndex):
        self.d.streamConfig(NumChannels=len(CHANNELS),
                            ChannelNumbers=CHANNELS,
                            ChannelOptions=len(CHANNELS)*[DIFFERENTIAL | gainIndex],
                            SampleFrequency=FREQ
                            )
        self.missed = 0
        data = []
        self.output = []
        for ch in CHANNELS:
            self.output.append([])

        self.start = datetime.now()
        self.d.streamStart()
        for r in self.d.streamData():
            if r is not None:
                # stop condition
                if ((datetime.now() - self.start).seconds >= MAX_TIME):
                    break

                # check for errors
                if r['errors'] != 0:
                    pass

                # check for underflow
                if r['numPackets'] != self.d.packetsPerRequest:
                    pass

                # check for missed packets
                if r['missed'] != 0:
                    self.missed += r['missed']

                data.append(r)

        self.d.streamStop()
        self.stop = datetime.now()

        total = len(data) * self.d.packetsPerRequest * self.d.streamSamplesPerPacket
        total -= self.missed
        runTime = (self.stop-self.start).seconds + float((self.stop-self.start).microseconds)/1000000

        self.dt = runTime/float(total)
   
        for result in data:
            for (counter, channel) in enumerate(CHANNELS):
                self.output[counter].extend(result['AIN' + str(channel)])
        
       
class SimplePlot(Canvas):
    def __init__(self, master, **kwargs):
        Canvas.__init__(self, master, **kwargs)
        self.xScale = 1
        self.xOffset = 0
        self.yScale = 1
        self.yOffset = 0
    
    def setscale(self, xmin, xmax, ymin, ymax):
        self.xScale = (self.winfo_width()-1) / float(xmax - xmin)
        self.xOffset = -xmin
        self.yScale = (self.winfo_height()) / float(ymax - ymin) 
        self.yOffset = -ymin
        
    def plot(self, x, y, c):    
        u = (self.xOffset + x) * self.xScale
        v = (self.yOffset + y) * self.yScale
        self.create_line(u, v, u+1, v, fill=c)

        
class StatefulButton(Button):
    def __init__(self, master, **kwargs):
        Button.__init__(self, master, **kwargs)

    def enable(self):
        self.config(state=NORMAL)

    def disable(self):
        self.config(state=DISABLED)


class StatusBar(Frame):

    def __init__(self, master):
        Frame.__init__(self, master)
        self.label = Label(self, bd=1, relief=SUNKEN, anchor=W)
        self.label.pack(fill=X)

    def set(self, format, *args):
        self.label.config(text=format % args)
        self.label.update_idletasks()

    def clear(self):
        self.label.config(text="")
        self.label.update_idletasks()

root = Tk()
app = App(root)
app.set_status('Ready.')
root.resizable(0,0)
root.mainloop()
root.destroy()
