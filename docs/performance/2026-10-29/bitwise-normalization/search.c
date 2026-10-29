// Deterministic coordinate search in GF(256), polynomial 0x1c3.
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
static unsigned char M[256][256], inv[256];
static const unsigned char T[16][16] = {{106,107,202,203,176,98,59,204,107,61,40,186,53,182,175,105},{229,106,107,202,203,176,98,59,204,107,61,40,186,53,182,175},{163,229,106,107,202,203,176,98,59,204,107,61,40,186,53,182},{107,163,229,106,107,202,203,176,98,59,204,107,61,40,186,53},{215,107,163,229,106,107,202,203,176,98,59,204,107,61,40,186},{205,215,107,163,229,106,107,202,203,176,98,59,204,107,61,40},{97,205,215,107,163,229,106,107,202,203,176,98,59,204,107,61},{92,97,205,215,107,163,229,106,107,202,203,176,98,59,204,107},{138,92,97,205,215,107,163,229,106,107,202,203,176,98,59,204},{199,138,92,97,205,215,107,163,229,106,107,202,203,176,98,59},{148,199,138,92,97,205,215,107,163,229,106,107,202,203,176,98},{3,148,199,138,92,97,205,215,107,163,229,106,107,202,203,176},{241,3,148,199,138,92,97,205,215,107,163,229,106,107,202,203},{40,241,3,148,199,138,92,97,205,215,107,163,229,106,107,202},{145,40,241,3,148,199,138,92,97,205,215,107,163,229,106,107},{207,145,40,241,3,148,199,138,92,97,205,215,107,163,229,106}};
static uint64_t state=0x8515133731415926ULL;
static uint64_t next(void){state^=state<<13;state^=state>>7;state^=state<<17;return state;}
static void leaves(unsigned char *out,const unsigned char *t,int n){
 if(n==1){out[0]=t[0];return;}
 int m=n/2,len=1;for(int k=m;k>1;k/=2)len*=3;
 unsigned char a[64],b[64],c[64];
 for(int i=0;i<m;i++)for(int j=0;j<m;j++){a[i*m+j]=t[i*n+j];b[i*m+j]=t[i*n+j]^t[i*n+j+m];c[i*m+j]=t[i*n+j]^t[(i+m)*n+j];}
 leaves(out,a,m);leaves(out+len,b,m);leaves(out+2*len,c,m);
}
static int score(const int *q,int *gamma,int *zeros,int *units){
 unsigned char s[16],si[16],t[256],leaf[81];int h[256]={0};
 for(int i=0;i<16;i++){s[i]=1;for(int b=0;b<4;b++)if(i&(1<<b))s[i]=M[s[i]][q[b]];si[i]=inv[s[i]];}
 for(int i=0;i<16;i++)for(int j=0;j<16;j++)t[i*16+j]=M[s[i]][M[T[i][j]][si[j]]];
 leaves(leaf,t,16);for(int i=0;i<81;i++)h[leaf[i]]++;
 int mode=1;for(int i=2;i<256;i++)if(h[i]>h[mode])mode=i;
 *gamma=inv[mode];*zeros=h[0];*units=h[mode];return 81-h[0]-h[mode];
}
int main(int argc,char **argv){
 int restarts=argc>1?atoi(argv[1]):1000,best=100;
 for(int a=0;a<256;a++)for(int b=0;b<256;b++){int x=a,y=b,z=0;for(int k=0;k<8;k++){if(y&1)z^=x;x=(x<<1)^((x&128)?0x1c3:0);y>>=1;}M[a][b]=z;if(z==1)inv[a]=b;}
 unsigned long long evals=0;
 for(int start=0;start<restarts;start++){
  int q[4],g,z,u;for(int i=0;i<4;i++)q[i]=start?1+next()%255:1;
  for(int iter=0;iter<6;iter++){
   int changed=0;for(int axis=0;axis<4;axis++){
    int old=q[axis],local=100,chosen=old;
    for(int v=1;v<256;v++){q[axis]=v;int c=score(q,&g,&z,&u);evals++;if(c<local||(c==local&&v==old)){local=c;chosen=v;}}
    q[axis]=chosen;changed|=chosen!=old;
    int c=score(q,&g,&z,&u);
    if(c<best){best=c;printf("{\"evaluations\":%llu,\"restart\":%d,\"q\":[%d,%d,%d,%d],\"gamma\":%d,\"gfni\":%d,\"zeros\":%d,\"units\":%d}\n",evals,start,q[0],q[1],q[2],q[3],g,c,z,u);fflush(stdout);}
   }if(!changed)break;
  }
 }
 fprintf(stderr,"evaluations=%llu restarts=%d best=%d\n",evals,restarts,best);
}
