// ###
// ###
// ### Practical Course: GPU Programming in Computer Vision
// ###
// ###
// ### Technical University Munich, Computer Vision Group
// ### Winter Semester 2013/2014, March 3 - April 4
// ###
// ###
// ### Evgeny Strekalovskiy, Maria Klodt, Jan Stuehmer, Mohamed Souiai
// ###
// ###
// ###



// ###
// ###
// ### TODO: For every student of your group, please provide here:
// ###
// ### name, email, login username (for example p123)
// ###
// ###


#include "aux.h"
#include <iostream>
#include <math.h>
using namespace std;

// uncomment to use the camera
//#define CAMERA

// Absolute value
__host__ __device__ float absolute(float2 z) {
    
    float value = sqrt(z.x*z.x + z.y*z.y);
    return value;
}

// Add two complex numbers
__host__ __device__ float2 add(float2 z, float2 c) {
    
    float2 value; 
    value.x = z.x + c.x;
    value.y = z.y + c.y;
    return value;
}

// Multiply two complex numbers
__host__ __device__ float2 multiply(float2 z, float2 c) {
    
    float2 value; 
    value.x = (z.x * c.x) - (z.y * c.y);  
    value.y = (z.x * c.y) + (z.y * c.x);		  
    return value;
}

// Mandelbrot Kernel
__global__ void mandelbrot_image(float2 *d_map, float *d_out, int N, int width, int height) {
    // get thread id
    int x = threadIdx.x + blockDim.x * blockIdx.x;
    int y = threadIdx.y + blockDim.y * blockIdx.y;
    int index = x + y * width;
       
    // initialization
    int n = 0;   
    float2 c = d_map[index];
    float2 z = c;
    float modZ = absolute(z);
    
    // only threads inside array range compute
    if (x<width && y<height) 
    {
    
        while(modZ < 2 && n < N)
        {
            float2 sqZ = multiply(z, z); // z^2 - z square
            z = add(sqZ, c);             // z = z^2 + c
            modZ = absolute(z);          // |z|
            n++;
        }
	// set grayscale value
        d_out[index] = 1.f - ((1.f * n)/N); 
    }                                     
}

// Mapping Kernel
__global__ void mapping_image(float2* d_map, float2 center, float radius, int width, int height) {
    // get thread id
    int x = threadIdx.x + blockDim.x * blockIdx.x;
    int y = threadIdx.y + blockDim.y * blockIdx.y;
    int index = x + y * width;
    
    // To prevent stretching	
    int w = min(width, height);	   
    int h = w;	   

    
    float deltaX = 2.f * radius / w;
    float deltaY = 2.f * radius / h;
    
    // only threads inside array range compute
    if (x<width && y<height) 
    {
        // Points in complex space
        float mandelbrotX = center.x + deltaX*(x - (w/2.f));
        float mandelbrotY = center.y + deltaY*(y - (h/2.f)); 

	// Mapping to pixels
        float2 tmp; 
        tmp.x = mandelbrotX;
        tmp.y = mandelbrotY;        
        d_map[index] = tmp;
        
    }   
        
}


int main(int argc, char **argv)
{
    // Before the GPU can process your kernels, a so called "CUDA context" must be initialized
    // This happens on the very first call to a CUDA function, and takes some time (around half a second)
    // We will do it right here, so that the run time measurements are accurate
    cudaDeviceSynchronize();  CUDA_CHECK;




    // Reading command line parameters:
    // getParam("param", var, argc, argv) looks whether "-param xyz" is specified, and if so stores the value "xyz" in "var"
    // If "-param" is not specified, the value of "var" remains unchanged
    //
    // return value: getParam("param", ...) returns true if "-param" is specified, and false otherwise

#ifdef CAMERA
#else
#endif
    
    // number of computation repetitions to get a better run time measurement
    int repeats = 1;
    getParam("repeats", repeats, argc, argv);
    cout << "repeats: " << repeats << endl;
    
    // load the input image as grayscale if "-gray" is specifed
    bool gray = false;
    getParam("gray", gray, argc, argv);
    cout << "gray: " << gray << endl;



    // Init camera / Load input image
#ifdef CAMERA

    // Init camera
  	cv::VideoCapture camera(0);
  	if(!camera.isOpened()) { cerr << "ERROR: Could not open camera" << endl; return 1; }
    int camW = 640;
    int camH = 480;
  	camera.set(CV_CAP_PROP_FRAME_WIDTH,camW);
  	camera.set(CV_CAP_PROP_FRAME_HEIGHT,camH);
    // read in first frame to get the dimensions
    cv::Mat mIn;
    camera >> mIn;
    
#else

    
#endif

    // get image dimensions
    int w = 640;         // width
    int h = 480;         // height
    int nc = 1;  // number of channels
    cout << "Output Image: " << w << " x " << h << endl;




    // Set the value of X
    float centerX;
    bool retX = getParam("x", centerX, argc, argv);
    if (!retX) { cerr << "ERROR: no X value specified" << endl;
    		 cout << "Usage: " << argv[0] << " -x Value(in float)" << endl; return 1; }
    
    // Set the value of Y
    float centerY;
    bool retY = getParam("y", centerY, argc, argv);
    if (!retY) { cerr << "ERROR: no Y value specified" << endl;
		 cout << "Usage: " << argv[0] << " -y Value(in float)" << endl; return 1; }

    float2 center;
    center.x = centerX;
    center.y = centerY;
    
    // Set the value of radius
    float radius;
    bool retR = getParam("rad", radius, argc, argv);
    if (!retR) { cerr << "ERROR: no radius specified" << endl;
    		 cout << "Usage: " << argv[0] << " -rad Value(in float)" << endl; return 1; }
    
    // Set the value of N
    int N;
    bool retN = getParam("N", N, argc, argv);
    if (!retN) { cerr << "ERROR: no N specified" << endl;
		 cout << "Usage: " << argv[0] << " -N Value(in float)" << endl; return 1; }
    
    
    // mOut will be a grayscale image, 1 layer
    cv::Mat mOut(h,w,CV_32FC1);    



    // Allocate arrays
    // input/output image width: w
    // input/output image height: h
    // input image number of channels: nc
    // output image number of channels: mOut.channels(), as defined above (nc, 3, or 1)

    // allocate raw input image array
    float *imgOut  = new float[(size_t)w*h*nc];
    float2 *imgMap  = new float2[(size_t)w*h*nc];
   

    // For camera mode: Make a loop to read in camera frames
#ifdef CAMERA
    // Read a camera image frame every 30 milliseconds:
    // cv::waitKey(30) waits 30 milliseconds for a keyboard input,
    // returns a value <0 if no key is pressed during this time, returns immediately with a value >=0 if a key is pressed
    while (cv::waitKey(30) < 0)
    {
    // Get camera image
    camera >> mIn;
    // convert to float representation (opencv loads image values as single bytes by default)
    mIn.convertTo(mIn,CV_32F);
    // convert range of each channel to [0,1] (opencv default is [0,255])
    mIn /= 255.f;
#endif

    // Init raw input image array
    // opencv images are interleaved: rgb rgb rgb...  (actually bgr bgr bgr...)
    // But for CUDA it's better to work with layered images: rrr... ggg... bbb...
    // So we will convert as necessary, using interleaved "cv::Mat" for loading/saving/displaying, and layered "float*" for CUDA computations
   
    // ask user if want to run CPU or GPU
    string hardware = "";
    bool retH = getParam("h", hardware, argc, argv);
    if (!retH) cerr << "ERROR: no hardware (CPU / GPU) specified" << endl;
    if (argc <= 1) { cout << "Usage: " << argv[0] << " -h CPU|GPU" << endl; return 1; }

    Timer timer; timer.start();

    // GPU version 
    if(hardware == "GPU")
    {
        int n = w*h;

        float *h_Out = imgOut;
        float2 *h_Map = imgMap;
                            
        // define block and grid sizes - 1D assumed
        // setting a block of 16 * 16 threads
        dim3 block = dim3(16, 16, 1);
        dim3 grid = dim3((w + block.x - 1) / block.x, (h + block.y - 1) / block.y, 1);

        
        // alloc GPU memeory and copy data
        float *d_Out;
        cudaMalloc((void **) &d_Out, n * sizeof(float));
        cudaMemcpy(d_Out, h_Out, n * sizeof(float), cudaMemcpyHostToDevice);    
        
        float2 *d_Map;
        cudaMalloc((void **) &d_Map, n * sizeof(float2));
        cudaMemcpy(d_Map, h_Map, n * sizeof(float2), cudaMemcpyHostToDevice);    
        
        
        // call kernel for mapping pixels to complex numbers
        mapping_image<<<grid, block>>>(d_Map, center, radius, w, h);
        
        
        // wait for kernel call to finish
        cudaDeviceSynchronize();
        
        // check for error
        CUDA_CHECK;
        
        // copy back data
        cudaMemcpy(h_Map, d_Map, n * sizeof(float2), cudaMemcpyDeviceToHost);                                          

        // call kernel for Mandelbrot set
        mandelbrot_image<<<grid, block>>>(d_Map, d_Out, N, w, h);
        
        
        // wait for kernel call to finish
        cudaDeviceSynchronize();
        
        // check for error
        CUDA_CHECK;
        
        // copy back data
        cudaMemcpy(h_Out, d_Out, n * sizeof(float), cudaMemcpyDeviceToHost);                                          
                
        // free GPU array
        cudaFree(d_Out);
        cudaFree(d_Map);
    }
    
    else {
        cout << "Invalid hardware " << hardware << endl;
        return 2;
    }
              
        
    
    timer.end();  float t = timer.get();  // elapsed time in seconds
    cout << "time: " << t*1000 << " ms" << endl;

    // show output image: first convert to interleaved opencv format from the layered raw array    
    convert_layered_to_mat(mOut, imgOut);
    showImage("Output", mOut, 40+w+40, 40);            
    

    // ### Display your own output images here as needed

#ifdef CAMERA
    // end of camera loop
    }
#else
    // wait for key inputs
    cv::waitKey(0);
#endif




    // save input and result
    //cv::imwrite("image_input.png",mIn*255.f);  // "imwrite" assumes channel range [0,255]
    cv::imwrite("image_result.png",mOut*255.f);

    // free allocated arrays

    delete[] imgOut;
       

    // close all opencv windows
    cvDestroyAllWindows();
    return 0;
}



