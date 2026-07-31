#include <ApplicationServices/ApplicationServices.h>
#include <stdio.h>
int main(void){
  CGDirectDisplayID ids[8]; uint32_t n=0;
  CGGetActiveDisplayList(8, ids, &n);
  double minx=1e9,miny=1e9,maxx=-1e9,maxy=-1e9;
  for(uint32_t i=0;i<n;i++){
    CGRect r=CGDisplayBounds(ids[i]);
    printf("display %u id=%u  origin=(%.0f,%.0f) size=%.0fx%.0f  %s\n", i, ids[i],
      r.origin.x, r.origin.y, r.size.width, r.size.height,
      CGDisplayIsMain(ids[i])?"[main]":"");
    if(r.origin.x<minx)minx=r.origin.x;
    if(r.origin.y<miny)miny=r.origin.y;
    if(r.origin.x+r.size.width>maxx)maxx=r.origin.x+r.size.width;
    if(r.origin.y+r.size.height>maxy)maxy=r.origin.y+r.size.height;
  }
  printf("\n전체 bounding box: x %.0f~%.0f, y %.0f~%.0f  (%.0fx%.0f)\n", minx,maxx,miny,maxy,maxx-minx,maxy-miny);
  printf("bounding box 중앙: (%.0f, %.0f)\n", (minx+maxx)/2, (miny+maxy)/2);
  return 0;
}
