import Tkinter

class SimplePlot(Tkinter.Canvas):
    def __init__(self, master, **kwargs):
        Tkinter.Canvas.__init__(self, master, **kwargs)
        self.xScale = 1
        self.xOffset = 0
        self.yScale = 1
        self.yOffset = 0
    
    def setscale(self, xmin, xmax, ymin, ymax):
        self.xScale = (self.winfo_width()) / float(xmax - xmin)
        self.xOffset = -xmin
        self.yScale = (self.winfo_height()) / float(ymax - ymin) 
        self.yOffset = -ymin
        print xmin, xmax, ymin, ymax
        print xmax - xmin, ymax - ymin, self.winfo_width(), self.winfo_height()
        print self.xScale, self.xOffset, self.yScale, self.yOffset
        
    def plot(self, x, y, c):    
        u = (self.xOffset + x) * self.xScale
        v = (self.yOffset + y) * self.yScale
        print u,v
        self.create_line(u, v+2, u+2, v, fill=c)
                          

#
# test program

import random, time

root = Tkinter.Tk()
root.title("demoSimplePlot")

widget = SimplePlot(root, bg="black")
widget.pack(fill="both", expand=1)

widget.update() # display the widget

data = [1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,4,3,2,1]
data = [y * 10 for y in data]

dt=  0.1

t0 = time.time()

x = 0

widget.setscale(0, dt*len(data), min(data), max(data))

for y in data:
    widget.plot(x, y, 'white')
    x += dt

widget.update() # make sure everything is drawn

print time.time() - t0, "seconds"
root.mainloop()
