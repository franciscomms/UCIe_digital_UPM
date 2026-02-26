package edu.berkeley.cs.ucie.digital

import chisel3._

object LinkTrainingState extends ChiselEnum {
  val reset, sbInit, mbInit, mbTrain, linkInit, active, linkError, retrain =
    Value
}
