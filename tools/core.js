// Dragon Palm CPU + memory + boot-screen core.
// Shared, single source of truth: index.html loads this with <script src>
// (works over file://, no build), and Node tests/tools require() it.
// Browser-specific concerns (canvas render, input wiring, audio, cart loading)
// live in the host, not here.
class DragonPalmCore{
  RAM=new Uint8Array(16384);A=0;X=0;Y=0;PC=0;input=0;boot=1;by=-20;beeped=0
  F={D:0xe999e,E:0xf8e8f,C:0xf888f,N:0x9db99,T:0xf4444,O:0xf999f,U:0x9999f,G:0xf8b9f,H:0x99f99}
  p(x,y,c){
    if((x|y)&~127)return
    let o=8192+(y*128+x>>1),v=this.RAM[o]
    this.RAM[o]=x&1?v&240|c:v&15|c<<4
  }
  t(y){
    let x=2
    for(let c of'DECENT ENOUGH'){
      let m=this.F[c]
      if(!m){x+=6;continue}
      for(let i=20;i--;)if(m>>i&1){
        let X=x+((19-i)&3)*2,Y=y+((19-i)>>2)*2
        this.p(X,Y,7);this.p(X+1,Y,7);this.p(X,Y+1,7);this.p(X+1,Y+1,7)
      }
      x+=10
    }
  }
  frame(){
    if(this.boot){
      this.RAM.fill(0,8192);this.t(this.by)
      let h=this.by==59&&!this.beeped
      this.beeped|=h;this.by+=this.by<59
      return h
    }
    for(let i=500;i--;)this.step()
  }
  step(){
    let r=this.RAM,p=this.PC&8191,o=r[p++],a
    switch(o){
      case 1:this.A=r[p++];break
      case 2:a=r[p++]|r[p++]<<8;this.A=a==16384?this.input:r[a&16383];break
      case 3:a=r[p++]|r[p++]<<8;if(a<16384)r[a]=this.A;break
      case 4:this.A=this.A+this.X&255;break
      case 5:this.A=this.A-this.X&255;break
      case 6:p=r[p]|r[p+1]<<8;break
      case 7:a=r[p++]|r[p++]<<8;if(this.A)p=a;break
      case 8:this.p(this.X,this.Y,this.A&15);break
      case 9:this.A=this.input;break
      case 10:this.X=r[p++];break
      case 11:this.Y=r[p++];break
    }
    this.PC=p&8191
  }
}
if(typeof module!=='undefined')module.exports={DragonPalmCore}
