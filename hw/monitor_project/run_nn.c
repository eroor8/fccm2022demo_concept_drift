#define L1_IN  784
#define L1_OUT 1000
#define L2_IN L1_OUT
#define L2_OUT 1000
#define L3_IN L2_OUT
#define L3_OUT 10
#define NPARAMS (L1_OUT + L1_IN * L1_OUT + L2_OUT + L2_IN * L2_OUT + L3_OUT + L3_IN * L3_OUT)

volatile unsigned *hex = (volatile unsigned *) 0x00001010; /* hex display PIO */
volatile unsigned *wordcpy_acc = (volatile unsigned *) 0x00001040; /* memory copy accelerator */
volatile unsigned *dnn_acc = (volatile unsigned *) 0x00001080; /* DNN accelerator */

/* normally these would be contiguous but it's nice to know where they are for debugging */
volatile int *nn      = (volatile int *) 0x0a000000; /* neural network biases and weights */
volatile int *input   = (volatile int *) 0x0a800000; /* input image */
volatile int *l1_acts = (volatile int *) 0x0a801000; /* activations of layer 1 */
volatile int *l2_acts = (volatile int *) 0x0a802000; /* activations of layer 2 */
volatile int *l3_acts = (volatile int *) 0x0a803000; /* activations of layer 3 (outputs) */

void main() {
    *(wordcpy_acc + 2) = (unsigned) 0;
    return;
}
