pragma circom 2.0.0;

// from circomlib
include "./eddsa.circom";

template Main() {
  signal input msg[16];
  signal input A[128];
  signal input AA[128];
  signal input R8[256];
  signal input S[256];
  signal output out;
  var i;

  component c = EdDSAVerifier(16);
  c.msg <== msg;
  // split public key in halves
  //  since any more public signals
  //  makes the generated solidity verifier contract
  //  >24kb
  for (i=0; i<128; i++) {
      c.A[i] <== A[i];
      c.A[128+i] <== AA[i];
  }
  c.R8 <== R8;
  c.S <== S;

  out <== 1;
}

component main {public [msg, A]} = Main();

