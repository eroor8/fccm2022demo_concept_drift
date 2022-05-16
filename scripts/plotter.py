import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from matplotlib.figure import Figure
from matplotlib import gridspec
from matplotlib.backends.backend_tkagg import (FigureCanvasTkAgg, NavigationToolbar2Tk)
import tkinter as tk
from tkinter import *
import os
import subprocess
import time
from functools import partial
from PIL import ImageTk, Image

windows = False
quartus_dir_win="c:/intelFPGA_lite/18.1/quartus/bin64"
quartus_dir_lin="/home/esther/intelFPGA_lite/18.0/quartus/bin"
if (windows):
    quartus_dir = quartus_dir_win
else:
    quartus_dir = quartus_dir_lin
    
linelist_acc=[0,0,0]
linelist_ang=[0,0,0]

def plot(t=0):
    def animate(i):
        # Clear the line we currently are drawing.
        # Every refresh we re-draw the whole thing.
        if not (linelist_ang[t] == 0):
            cl = linelist_ang[t].pop(0)
            cl.remove()        
        if not (linelist_acc[t] == 0):
            cl = linelist_acc[t].pop(0)
            cl.remove()

        # Open the appropriate file and read from it.
        ff = open(acc_file, 'r')
        lines = ff.readlines()
        lines_data = []
        angles_data = []
        curr_angle = 0
        last_angle = 0
        num_samples = int(e1.get())
        xax = range(0,len(lines)*int(num_samples/100),int(num_samples/100))

        ff = 0
        for l in lines:
            ff += 1
            if (ff > 75) and (cd_type == "zoom"):
                break
            data_int = int(l, 16)
            lines_data += [data_int]
            if not (t==0):
                angles_data += [int(curr_angle)]
            else: # For static data, angle is always 0.
                angles_data += [0]
            last_angle = int(curr_angle)
            curr_angle += max_angle/100

        # Choose the line style.
        col = "#0055B7"
        linestyle="solid"
        if (t == 1):
            col = "#40B4E5"
            linestyle="dashed"
        if (t == 2):
            col = "#6EC4E8"
            linestyle="dashdot"


        # Plot the line
        line_acc = ax.plot(xax[:len(lines_data)], lines_data, color=col, linestyle=linestyle)
        line_ang = ax2.plot(xax[:len(lines_data)], angles_data[:len(lines_data)], color=col, linestyle=linestyle)
        linelist_acc[t] = line_acc
        linelist_ang[t] = line_ang
        
        # Rotate digits onscreen
        imgi1 = ImageTk.PhotoImage(
            Image.open(img_dir + "1/img" + str(last_angle) + ".png").resize((118,118)))
        imgi3 = ImageTk.PhotoImage(
            Image.open(img_dir + "3/img" + str(last_angle) + ".png").resize((118,118)))
        imgi5 = ImageTk.PhotoImage(
            Image.open(img_dir + "5/img" + str(last_angle) + ".png").resize((118,118)))
        imgi7 = ImageTk.PhotoImage(
            Image.open(img_dir + "7/img" + str(last_angle) + ".png").resize((118,118)))
        imgi8 = ImageTk.PhotoImage(
            Image.open(img_dir + "8/img" + str(last_angle) + ".png").resize((118,118)))
        labi1.configure(image=imgi1)
        labi3.configure(image=imgi3)
        labi5.configure(image=imgi5)
        labi7.configure(image=imgi7)
        labi8.configure(image=imgi8)
        labi1.image = imgi1
        labi3.image = imgi3
        labi5.image = imgi5
        labi7.image = imgi7
        labi8.image = imgi8
            
    # Choose the file to read from and start the process!
    lrate = e2.get()
    if (lrate == "") or (t == 0) or (t == 1):
        lrate = 0
    lrate = int(float(lrate) * (2**8))
    lrate_b = bin(lrate & int("1"*16,2))[2:]
    lrate_b = ("{0:0>%s}" % (16)).format(lrate_b)
    print(lrate_b, "?????")
    
    start_img = 0
    cd_type = drift_type.get()    
    if (t > 0) and (cd_type == "rotation"):
        start_img = 10000
        ax.set_xlim([0,10000])
        ax2.set_xlim([0,10000])
    elif (t > 0) and (cd_type == "zoom"):
        start_img = 20000
        ax.set_xlim([0,7500])
        ax2.set_xlim([0,7500])
    elif (t > 0):
        start_img = 30000
    start_imgb = bin(start_img & int("1"*16,2))[2:]
    start_imgb = ("{0:0>%s}" % (16)).format(start_imgb)

    img_dir = "./images/" + cd_type + "/"
    #assert(0)

    num_samples = int(e1.get())
    max_angle = 0
    if (t > 0) and (cd_type == "rotation"):
        max_angle = 90 #int(e1.get()
    elif (t > 0) and (cd_type == "zoom"):
        max_angle = 200
    elif (t > 0) and (cd_type == "shear"):
        max_angle = 200

    sample_rate = int(e1.get())
    sample_rateb = bin(sample_rate & int("1"*16,2))[2:]
    sample_rateb = ("{0:0>%s}" % (16)).format(sample_rateb)

    if (t == 0):
        acc_file="current_accuracies0.txt"
        proc = subprocess.Popen([quartus_dir + '/quartus_stp', '--script=load_mem.tcl','-lrate', str(lrate_b),'-start_img', str(start_imgb),'-filename', acc_file,'-restore', "True",'-sample_rate', "True"])
    if (t == 1):
        acc_file="current_accuracies1.txt"
        proc = subprocess.Popen([quartus_dir + '/quartus_stp', '--script=load_mem.tcl','-lrate', str(lrate_b),'-start_img', str(start_imgb),'-filename', acc_file,'-restore', "True",'-sample_rate', "True"])
    if (t == 2):
        acc_file="current_accuracies2.txt"
        proc = subprocess.Popen([quartus_dir + '/quartus_stp', '--script=load_mem.tcl','-lrate', str(lrate_b),'-start_img', str(start_imgb),'-filename', acc_file,'-restore', "False",'-sample_rate', "True"])
    time.sleep(1)
    ax2.set_ylim([-1,max(max_angle,100)])
    if (windows):
        frames = 90
        interval = 100
    else:
        frames = 200
        interval = 10
    ani = FuncAnimation(fig, animate, interval=100, frames=50, repeat=False)
    canv.draw()

# Main window
window = Tk()
window.title("Online Training with Concept Drift on FPGA")
window.geometry("1500x1000")
window.configure(bg="#002145")

# Add buttons.
if (windows):
    ff = 15
else:
    ff = 17
plot_button0 = Button(master=window, command = partial(plot,0),
     height = 2, bg="#0055B7", width = 35,
                      text = "Accuracy with Static Data", font=17)
plot_button1 = Button(master=window, command = partial(plot,1),
     height = 2, bg="#40B4E5", width = 35,
                      text = "Accuracy with Concept Drift ", font=17)
plot_button2 = Button(master=window, command = partial(plot,2),
     height = 2, bg="#6EC4E8", width = 35,
                      text = "Accuracy with Concept and Online Training", font=17)
if (windows):
    yy = 90
else:
    yy = 100
plot_button0.place(x=20,y=130)
plot_button1.place(x=430,y=130)
plot_button2.place(x=840,y=130)

# Other input fields / options  - Not yet implemented. 
label = Label(window, text="Concept Drift Rate (# Training Samples):",
              fg="white", bg="#002145", font=20)
label2 = Label(window, text="Learning Rate:", fg="white", bg="#002145", font=20)
label3 = Label(window, text="Concept Drift Type:", fg="white", bg="#002145", font=20)
if (windows):
    xx = 767
else:
    xx = 810
label.place(x = xx, y= 5)
label2.place(x = 1030, y= 35)
label3.place(x = 900, y= 65)
e1 = Entry(window, font=20, width=5)
e1.insert(END, "10000")
e1.place(x=1170, y = 5)
e2 = Entry(window, font=20, width=5)
#e2.insert(END, "0.02")
e2.place(x=1170, y = 35)

# Choose the drift Type
options = ["rotation", "zoom", "shear"]
drift_type = StringVar()
drift_type.set("rotation")
drop = OptionMenu(window, drift_type, *options)
drop.place(x=1170, y=65)

# UBC Logo. 
fr = Frame(window, width=30,height=30)
fr.place(x=1272,y=5)
img = ImageTk.PhotoImage(Image.open("./images/ubc.jpg").resize((118,140)))
lab = Label(fr, image=img)
lab.pack()

# Rotating digits
# 0 
fri0 = Frame(window, width=30,height=30)
fri0.place(x=1242,y=160)
imgi0 = ImageTk.PhotoImage(
    Image.open("./images/rotation/0/img0.png").resize((118,118)))
labi0 = Label(fri0, image=imgi0)
labi0.pack()
# 1
fri1 = Frame(window, width=30,height=30)
fri1.place(x=1242,y=290)
imgi1 = ImageTk.PhotoImage(
    Image.open("./images/rotation/1/img0.png").resize((118,118)))
labi1 = Label(fri1, image=imgi1)
labi1.pack()
# 2 
fri2 = Frame(window, width=30,height=30)
fri2.place(x=1242,y=420)
imgi2 = ImageTk.PhotoImage(
    Image.open("./images/rotation/2/img0.png").resize((118,118)))
labi2 = Label(fri2, image=imgi2)
labi2.pack()
# 3 
fri3 = Frame(window, width=30,height=30)
fri3.place(x=1242,y=550)
imgi3 = ImageTk.PhotoImage(
    Image.open("./images/rotation/3/img0.png").resize((118,118)))
labi3 = Label(fri3, image=imgi3)
labi3.pack()
# 4 
fri4 = Frame(window, width=30,height=30)
fri4.place(x=1242,y=680)
imgi4 = ImageTk.PhotoImage(
    Image.open("./images/rotation/4/img0.png").resize((118,118)))
labi4 = Label(fri4, image=imgi4)
labi4.pack()
# 5 
fri5 = Frame(window, width=30,height=30)
fri5.place(x=1372,y=160)
imgi5 = ImageTk.PhotoImage(
    Image.open("./images/rotation/5/img0.png").resize((118,118)))
labi5 = Label(fri5, image=imgi5)
labi5.pack()
# 5 
fri6 = Frame(window, width=30,height=30)
fri6.place(x=1372,y=290)
imgi6 = ImageTk.PhotoImage(
    Image.open("./images/rotation/6/img0.png").resize((118,118)))
labi6 = Label(fri6, image=imgi6)
labi6.pack()
# 7 
fri7 = Frame(window, width=30,height=30)
fri7.place(x=1372,y=420)
imgi7 = ImageTk.PhotoImage(
    Image.open("./images/rotation/7/img0.png").resize((118,118)))
labi7 = Label(fri7, image=imgi7)
labi7.pack()
# 8 
fri8 = Frame(window, width=30,height=30)
fri8.place(x=1372,y=550)
imgi8 = ImageTk.PhotoImage(
    Image.open("./images/rotation/8/img0.png").resize((118,118)))
labi8 = Label(fri8, image=imgi8)
labi8.pack()
# 9
fri9 = Frame(window, width=30,height=30)
fri9.place(x=1372,y=680)
imgi9 = ImageTk.PhotoImage(
    Image.open("./images/rotation/9/img0.png").resize((118,118)))
labi9 = Label(fri9, image=imgi9)
labi9.pack()

# Add the plot itself.
fig = plt.figure(figsize=(12.1,7.5), dpi=100)
fig.tight_layout(pad=0)
plt.rcParams.update({'font.size' : 13})
gs = gridspec.GridSpec(2,1,height_ratios=[2,1])
ax = plt.subplot(gs[0], ylabel="Accuracy (%)", xmargin=0.2)
ax2 = plt.subplot(gs[1], sharex=ax, ylabel="Angle (degrees)", xlabel="Input Index")
plt.subplots_adjust(left=0.1, right=0.95, bottom=0.1, top=0.95)
canv = FigureCanvasTkAgg(fig, master=window)
ax.margins(0.5)
ax.set_xlim([0,10000])
ax.set_ylim([40,100])
ax2.set_ylim([0,100])
canv.draw()
canv.get_tk_widget().place(x=20,y=190)

window.mainloop()

