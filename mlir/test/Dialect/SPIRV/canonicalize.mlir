// RUN: mlir-opt %s -split-input-file -pass-pipeline='func(canonicalize)' | FileCheck %s

//===----------------------------------------------------------------------===//
// spv.AccessChain
//===----------------------------------------------------------------------===//

func @combine_full_access_chain() -> f32 {
  // CHECK: %[[INDEX:.*]] = spv.constant 0
  // CHECK-NEXT: %[[VAR:.*]] = spv.Variable
  // CHECK-NEXT: %[[PTR:.*]] = spv.AccessChain %[[VAR]][%[[INDEX]], %[[INDEX]], %[[INDEX]]]
  // CHECK-NEXT: spv.Load "Function" %[[PTR]]
  %c0 = spv.constant 0: i32
  %0 = spv.Variable : !spv.ptr<!spv.struct<!spv.array<4x!spv.array<4xf32>>, !spv.array<4xi32>>, Function>
  %1 = spv.AccessChain %0[%c0] : !spv.ptr<!spv.struct<!spv.array<4x!spv.array<4xf32>>, !spv.array<4xi32>>, Function>
  %2 = spv.AccessChain %1[%c0, %c0] : !spv.ptr<!spv.array<4x!spv.array<4xf32>>, Function>
  %3 = spv.Load "Function" %2 : f32
  spv.ReturnValue %3 : f32
}

// -----

func @combine_access_chain_multi_use() -> !spv.array<4xf32> {
  // CHECK: %[[INDEX:.*]] = spv.constant 0
  // CHECK-NEXT: %[[VAR:.*]] = spv.Variable
  // CHECK-NEXT: %[[PTR_0:.*]] = spv.AccessChain %[[VAR]][%[[INDEX]], %[[INDEX]]]
  // CHECK-NEXT: %[[PTR_1:.*]] = spv.AccessChain %[[VAR]][%[[INDEX]], %[[INDEX]], %[[INDEX]]]
  // CHECK-NEXT: spv.Load "Function" %[[PTR_0]]
  // CHECK-NEXT: spv.Load "Function" %[[PTR_1]]
  %c0 = spv.constant 0: i32
  %0 = spv.Variable : !spv.ptr<!spv.struct<!spv.array<4x!spv.array<4xf32>>, !spv.array<4xi32>>, Function>
  %1 = spv.AccessChain %0[%c0] : !spv.ptr<!spv.struct<!spv.array<4x!spv.array<4xf32>>, !spv.array<4xi32>>, Function>
  %2 = spv.AccessChain %1[%c0] : !spv.ptr<!spv.array<4x!spv.array<4xf32>>, Function>
  %3 = spv.AccessChain %2[%c0] : !spv.ptr<!spv.array<4xf32>, Function>
  %4 = spv.Load "Function" %2 : !spv.array<4xf32>
  %5 = spv.Load "Function" %3 : f32
  spv.ReturnValue %4: !spv.array<4xf32>
}

// -----

func @dont_combine_access_chain_without_common_base() -> !spv.array<4xi32> {
  // CHECK: %[[INDEX:.*]] = spv.constant 1
  // CHECK-NEXT: %[[VAR_0:.*]] = spv.Variable
  // CHECK-NEXT: %[[VAR_1:.*]] = spv.Variable
  // CHECK-NEXT: %[[VAR_0_PTR:.*]] = spv.AccessChain %[[VAR_0]][%[[INDEX]]]
  // CHECK-NEXT: %[[VAR_1_PTR:.*]] = spv.AccessChain %[[VAR_1]][%[[INDEX]]]
  // CHECK-NEXT: spv.Load "Function" %[[VAR_0_PTR]]
  // CHECK-NEXT: spv.Load "Function" %[[VAR_1_PTR]]
  %c1 = spv.constant 1: i32
  %0 = spv.Variable : !spv.ptr<!spv.struct<!spv.array<4x!spv.array<4xf32>>, !spv.array<4xi32>>, Function>
  %1 = spv.Variable : !spv.ptr<!spv.struct<!spv.array<4x!spv.array<4xf32>>, !spv.array<4xi32>>, Function>
  %2 = spv.AccessChain %0[%c1] : !spv.ptr<!spv.struct<!spv.array<4x!spv.array<4xf32>>, !spv.array<4xi32>>, Function>
  %3 = spv.AccessChain %1[%c1] : !spv.ptr<!spv.struct<!spv.array<4x!spv.array<4xf32>>, !spv.array<4xi32>>, Function>
  %4 = spv.Load "Function" %2 : !spv.array<4xi32>
  %5 = spv.Load "Function" %3 : !spv.array<4xi32>
  spv.ReturnValue %4 : !spv.array<4xi32>
}

// -----

//===----------------------------------------------------------------------===//
// spv.Bitcast
//===----------------------------------------------------------------------===//

func @convert_bitcast_full(%arg0 : vector<2xf32>) -> f64 {
  // CHECK: %[[RESULT:.*]] = spv.Bitcast {{%.*}} : vector<2xf32> to f64
  // CHECK-NEXT: spv.ReturnValue %[[RESULT]]
  %0 = spv.Bitcast %arg0 : vector<2xf32> to vector<2xi32>
  %1 = spv.Bitcast %0 : vector<2xi32> to i64
  %2 = spv.Bitcast %1 : i64 to f64
  spv.ReturnValue %2 : f64
}

// -----

func @convert_bitcast_multi_use(%arg0 : vector<2xf32>, %arg1 : !spv.ptr<i64, Uniform>) -> f64 {
  // CHECK: %[[RESULT_0:.*]] = spv.Bitcast {{%.*}} : vector<2xf32> to i64
  // CHECK-NEXT: %[[RESULT_1:.*]] = spv.Bitcast {{%.*}} : vector<2xf32> to f64
  // CHECK-NEXT: spv.Store {{".*"}} {{%.*}}, %[[RESULT_0]]
  // CHECK-NEXT: spv.ReturnValue %[[RESULT_1]]
  %0 = spv.Bitcast %arg0 : vector<2xf32> to i64
  %1 = spv.Bitcast %0 : i64 to f64
  spv.Store "Uniform" %arg1, %0 : i64
  spv.ReturnValue %1 : f64
}

// -----

//===----------------------------------------------------------------------===//
// spv.CompositeExtract
//===----------------------------------------------------------------------===//

// CHECK-LABEL: extract_vector
func @extract_vector() -> (i32, i32, i32) {
  // CHECK: spv.constant 42 : i32
  // CHECK: spv.constant -33 : i32
  // CHECK: spv.constant 6 : i32
  %0 = spv.constant dense<[42, -33, 6]> : vector<3xi32>
  %1 = spv.CompositeExtract %0[0 : i32] : vector<3xi32>
  %2 = spv.CompositeExtract %0[1 : i32] : vector<3xi32>
  %3 = spv.CompositeExtract %0[2 : i32] : vector<3xi32>
  return %1, %2, %3 : i32, i32, i32
}

// -----

// CHECK-LABEL: extract_array_final
func @extract_array_final() -> (i32, i32) {
  // CHECK: spv.constant 4 : i32
  // CHECK: spv.constant -5 : i32
  %0 = spv.constant [dense<[4, -5]> : vector<2xi32>] : !spv.array<1 x vector<2xi32>>
  %1 = spv.CompositeExtract %0[0 : i32, 0 : i32] : !spv.array<1 x vector<2 x i32>>
  %2 = spv.CompositeExtract %0[0 : i32, 1 : i32] : !spv.array<1 x vector<2 x i32>>
  return %1, %2 : i32, i32
}

// -----

// CHECK-LABEL: extract_array_interm
func @extract_array_interm() -> (vector<2xi32>) {
  // CHECK: spv.constant dense<[4, -5]> : vector<2xi32>
  %0 = spv.constant [dense<[4, -5]> : vector<2xi32>] : !spv.array<1 x vector<2xi32>>
  %1 = spv.CompositeExtract %0[0 : i32] : !spv.array<1 x vector<2 x i32>>
  return %1 : vector<2xi32>
}

// -----

// CHECK-LABEL: extract_from_not_constant
func @extract_from_not_constant() -> i32 {
  %0 = spv.Variable : !spv.ptr<vector<3xi32>, Function>
  %1 = spv.Load "Function" %0 : vector<3xi32>
  // CHECK: spv.CompositeExtract
  %2 = spv.CompositeExtract %1[0 : i32] : vector<3xi32>
  spv.ReturnValue %2 : i32
}

// -----

//===----------------------------------------------------------------------===//
// spv.constant
//===----------------------------------------------------------------------===//

// TODO(antiagainst): test constants in different blocks

func @deduplicate_scalar_constant() -> (i32, i32) {
  // CHECK: %[[CST:.*]] = spv.constant 42 : i32
  %0 = spv.constant 42 : i32
  %1 = spv.constant 42 : i32
  // CHECK-NEXT: return %[[CST]], %[[CST]]
  return %0, %1 : i32, i32
}

// -----

func @deduplicate_vector_constant() -> (vector<3xi32>, vector<3xi32>) {
  // CHECK: %[[CST:.*]] = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  %0 = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  %1 = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  // CHECK-NEXT: return %[[CST]], %[[CST]]
  return %0, %1 : vector<3xi32>, vector<3xi32>
}

// -----

func @deduplicate_composite_constant() -> (!spv.array<1 x vector<2xi32>>, !spv.array<1 x vector<2xi32>>) {
  // CHECK: %[[CST:.*]] = spv.constant [dense<5> : vector<2xi32>] : !spv.array<1 x vector<2xi32>>
  %0 = spv.constant [dense<5> : vector<2xi32>] : !spv.array<1 x vector<2xi32>>
  %1 = spv.constant [dense<5> : vector<2xi32>] : !spv.array<1 x vector<2xi32>>
  // CHECK-NEXT: return %[[CST]], %[[CST]]
  return %0, %1 : !spv.array<1 x vector<2xi32>>, !spv.array<1 x vector<2xi32>>
}

// -----

//===----------------------------------------------------------------------===//
// spv.IAdd
//===----------------------------------------------------------------------===//

// CHECK-LABEL: @iadd_zero
// CHECK-SAME: (%[[ARG:.*]]: i32)
func @iadd_zero(%arg0: i32) -> (i32, i32) {
  %zero = spv.constant 0 : i32
  %0 = spv.IAdd %arg0, %zero : i32
  %1 = spv.IAdd %zero, %arg0 : i32
  // CHECK: return %[[ARG]], %[[ARG]]
  return %0, %1: i32, i32
}

// CHECK-LABEL: @const_fold_scalar_iadd_normal
func @const_fold_scalar_iadd_normal() -> (i32, i32, i32) {
  %c5 = spv.constant 5 : i32
  %cn8 = spv.constant -8 : i32

  // CHECK: spv.constant 10
  // CHECK: spv.constant -16
  // CHECK: spv.constant -3
  %0 = spv.IAdd %c5, %c5 : i32
  %1 = spv.IAdd %cn8, %cn8 : i32
  %2 = spv.IAdd %c5, %cn8 : i32
  return %0, %1, %2: i32, i32, i32
}

// CHECK-LABEL: @const_fold_scalar_iadd_flow
func @const_fold_scalar_iadd_flow() -> (i32, i32, i32, i32) {
  %c1 = spv.constant 1 : i32
  %c2 = spv.constant 2 : i32
  %c3 = spv.constant 4294967295 : i32  // 2^32 - 1: 0xffff ffff
  %c4 = spv.constant -2147483648 : i32 // -2^31   : 0x8000 0000
  %c5 = spv.constant -1 : i32          //         : 0xffff ffff
  %c6 = spv.constant -2 : i32          //         : 0xffff fffe

  // 0x0000 0001 + 0xffff ffff = 0x1 0000 0000 -> 0x0000 0000
  // CHECK: spv.constant 0
  %0 = spv.IAdd %c1, %c3 : i32
  // 0x0000 0002 + 0xffff ffff = 0x1 0000 0001 -> 0x0000 0001
  // CHECK: spv.constant 1
  %1 = spv.IAdd %c2, %c3 : i32
  // 0x8000 0000 + 0xffff ffff = 0x1 7fff ffff -> 0x7fff ffff
  // CHECK: spv.constant 2147483647
  %2 = spv.IAdd %c4, %c5 : i32
  // 0x8000 0000 + 0xffff fffe = 0x1 7fff fffe -> 0x7fff fffe
  // CHECK: spv.constant 2147483646
  %3 = spv.IAdd %c4, %c6 : i32
  return %0, %1, %2, %3: i32, i32, i32, i32
}

// CHECK-LABEL: @const_fold_vector_iadd
func @const_fold_vector_iadd() -> vector<3xi32> {
  %vc1 = spv.constant dense<[42, -55, 127]> : vector<3xi32>
  %vc2 = spv.constant dense<[-3, -15, 28]> : vector<3xi32>

  // CHECK: spv.constant dense<[39, -70, 155]>
  %0 = spv.IAdd %vc1, %vc2 : vector<3xi32>
  return %0: vector<3xi32>
}

// -----

//===----------------------------------------------------------------------===//
// spv.IMul
//===----------------------------------------------------------------------===//

// CHECK-LABEL: @imul_zero_one
// CHECK-SAME: (%[[ARG:.*]]: i32)
func @imul_zero_one(%arg0: i32) -> (i32, i32) {
  // CHECK: %[[ZERO:.*]] = spv.constant 0
  %zero = spv.constant 0 : i32
  %one = spv.constant 1: i32
  %0 = spv.IMul %arg0, %zero : i32
  %1 = spv.IMul %one, %arg0 : i32
  // CHECK: return %[[ZERO]], %[[ARG]]
  return %0, %1: i32, i32
}

// CHECK-LABEL: @const_fold_scalar_imul_normal
func @const_fold_scalar_imul_normal() -> (i32, i32, i32) {
  %c5 = spv.constant 5 : i32
  %cn8 = spv.constant -8 : i32
  %c7 = spv.constant 7 : i32

  // CHECK: spv.constant 35
  // CHECK: spv.constant -40
  // CHECK: spv.constant -56
  %0 = spv.IMul %c7, %c5 : i32
  %1 = spv.IMul %c5, %cn8 : i32
  %2 = spv.IMul %cn8, %c7 : i32
  return %0, %1, %2: i32, i32, i32
}

// CHECK-LABEL: @const_fold_scalar_imul_flow
func @const_fold_scalar_imul_flow() -> (i32, i32, i32) {
  %c1 = spv.constant 2 : i32
  %c2 = spv.constant 4 : i32
  %c3 = spv.constant 4294967295 : i32  // 2^32 - 1 : 0xffff ffff
  %c4 = spv.constant -2147483649 : i32 // -2^31 - 1: 0x7fff ffff

  // (0xffff ffff << 1) = 0x1 ffff fffe -> 0xffff fffe
  // CHECK: %[[CST2:.*]] = spv.constant -2
  %0 = spv.IMul %c1, %c3 : i32
  // (0x7fff ffff << 1) = 0x0 ffff fffe -> 0xffff fffe
  %1 = spv.IMul %c1, %c4 : i32
  // (0x7fff ffff << 2) = 0x1 ffff fffc -> 0xffff fffc
  // CHECK: %[[CST4:.*]] = spv.constant -4
  %2 = spv.IMul %c4, %c2 : i32
  // CHECK: return %[[CST2]], %[[CST2]], %[[CST4]]
  return %0, %1, %2: i32, i32, i32
}


// CHECK-LABEL: @const_fold_vector_imul
func @const_fold_vector_imul() -> vector<3xi32> {
  %vc1 = spv.constant dense<[42, -55, 127]> : vector<3xi32>
  %vc2 = spv.constant dense<[-3, -15, 28]> : vector<3xi32>

  // CHECK: spv.constant dense<[-126, 825, 3556]>
  %0 = spv.IMul %vc1, %vc2 : vector<3xi32>
  return %0: vector<3xi32>
}

// -----

//===----------------------------------------------------------------------===//
// spv.ISub
//===----------------------------------------------------------------------===//

// CHECK-LABEL: @isub_x_x
func @isub_x_x(%arg0: i32) -> i32 {
  // CHECK: spv.constant 0
  %0 = spv.ISub %arg0, %arg0: i32
  return %0: i32
}

// CHECK-LABEL: @const_fold_scalar_isub_normal
func @const_fold_scalar_isub_normal() -> (i32, i32, i32) {
  %c5 = spv.constant 5 : i32
  %cn8 = spv.constant -8 : i32
  %c7 = spv.constant 7 : i32

  // CHECK: spv.constant 2
  // CHECK: spv.constant 13
  // CHECK: spv.constant -15
  %0 = spv.ISub %c7, %c5 : i32
  %1 = spv.ISub %c5, %cn8 : i32
  %2 = spv.ISub %cn8, %c7 : i32
  return %0, %1, %2: i32, i32, i32
}

// CHECK-LABEL: @const_fold_scalar_isub_flow
func @const_fold_scalar_isub_flow() -> (i32, i32, i32, i32) {
  %c1 = spv.constant 0 : i32
  %c2 = spv.constant 1 : i32
  %c3 = spv.constant 4294967295 : i32  // 2^32 - 1 : 0xffff ffff
  %c4 = spv.constant -2147483649 : i32 // -2^31 - 1: 0x7fff ffff
  %c5 = spv.constant -1 : i32          //          : 0xffff ffff
  %c6 = spv.constant -2 : i32          //          : 0xffff fffe

  // 0x0000 0000 - 0xffff ffff -> 0x0000 0000 + 0x0000 0001 = 0x0000 0001
  // CHECK: spv.constant 1
  %0 = spv.ISub %c1, %c3 : i32
  // 0x0000 0001 - 0xffff ffff -> 0x0000 0001 + 0x0000 0001 = 0x0000 0002
  // CHECK: spv.constant 2
  %1 = spv.ISub %c2, %c3 : i32
  // 0xffff ffff - 0x7fff ffff -> 0xffff ffff + 0x8000 0001 = 0x1 8000 0000
  // CHECK: spv.constant -2147483648
  %2 = spv.ISub %c5, %c4 : i32
  // 0xffff fffe - 0x7fff ffff -> 0xffff fffe + 0x8000 0001 = 0x1 7fff ffff
  // CHECK: spv.constant 2147483647
  %3 = spv.ISub %c6, %c4 : i32
  return %0, %1, %2, %3: i32, i32, i32, i32
}

// CHECK-LABEL: @const_fold_vector_isub
func @const_fold_vector_isub() -> vector<3xi32> {
  %vc1 = spv.constant dense<[42, -55, 127]> : vector<3xi32>
  %vc2 = spv.constant dense<[-3, -15, 28]> : vector<3xi32>

  // CHECK: spv.constant dense<[45, -40, 99]>
  %0 = spv.ISub %vc1, %vc2 : vector<3xi32>
  return %0: vector<3xi32>
}

// -----

//===----------------------------------------------------------------------===//
// spv.LogicalNot
//===----------------------------------------------------------------------===//

func @convert_logical_not_to_not_equal(%arg0: vector<3xi64>, %arg1: vector<3xi64>) -> vector<3xi1> {
  // CHECK: %[[RESULT:.*]] = spv.INotEqual {{%.*}}, {{%.*}} : vector<3xi64>
  // CHECK-NEXT: spv.ReturnValue %[[RESULT]] : vector<3xi1>
  %2 = spv.IEqual %arg0, %arg1 : vector<3xi64>
  %3 = spv.LogicalNot %2 : vector<3xi1>
  spv.ReturnValue %3 : vector<3xi1>
}

// -----

func @convert_logical_not_to_equal(%arg0: vector<3xi64>, %arg1: vector<3xi64>) -> vector<3xi1> {
  // CHECK: %[[RESULT:.*]] = spv.IEqual {{%.*}}, {{%.*}} : vector<3xi64>
  // CHECK-NEXT: spv.ReturnValue %[[RESULT]] : vector<3xi1>
  %2 = spv.INotEqual %arg0, %arg1 : vector<3xi64>
  %3 = spv.LogicalNot %2 : vector<3xi1>
  spv.ReturnValue %3 : vector<3xi1>
}

// -----

func @convert_logical_not_parent_multi_use(%arg0: vector<3xi64>, %arg1: vector<3xi64>, %arg2: !spv.ptr<vector<3xi1>, Uniform>) -> vector<3xi1> {
  // CHECK: %[[RESULT_0:.*]] = spv.INotEqual {{%.*}}, {{%.*}} : vector<3xi64>
  // CHECK-NEXT: %[[RESULT_1:.*]] = spv.IEqual {{%.*}}, {{%.*}} : vector<3xi64>
  // CHECK-NEXT: spv.Store "Uniform" {{%.*}}, %[[RESULT_0]]
  // CHECK-NEXT: spv.ReturnValue %[[RESULT_1]]
  %0 = spv.INotEqual %arg0, %arg1 : vector<3xi64>
  %1 = spv.LogicalNot %0 : vector<3xi1>
  spv.Store "Uniform" %arg2, %0 : vector<3xi1>
  spv.ReturnValue %1 : vector<3xi1>
}

// -----

func @convert_logical_not_to_logical_not_equal(%arg0: vector<3xi1>, %arg1: vector<3xi1>) -> vector<3xi1> {
  // CHECK: %[[RESULT:.*]] = spv.LogicalNotEqual {{%.*}}, {{%.*}} : vector<3xi1>
  // CHECK-NEXT: spv.ReturnValue %[[RESULT]] : vector<3xi1>
  %2 = spv.LogicalEqual %arg0, %arg1 : vector<3xi1>
  %3 = spv.LogicalNot %2 : vector<3xi1>
  spv.ReturnValue %3 : vector<3xi1>
}

// -----

func @convert_logical_not_to_logical_equal(%arg0: vector<3xi1>, %arg1: vector<3xi1>) -> vector<3xi1> {
  // CHECK: %[[RESULT:.*]] = spv.LogicalEqual {{%.*}}, {{%.*}} : vector<3xi1>
  // CHECK-NEXT: spv.ReturnValue %[[RESULT]] : vector<3xi1>
  %2 = spv.LogicalNotEqual %arg0, %arg1 : vector<3xi1>
  %3 = spv.LogicalNot %2 : vector<3xi1>
  spv.ReturnValue %3 : vector<3xi1>
}

// -----

//===----------------------------------------------------------------------===//
// spv.selection
//===----------------------------------------------------------------------===//

func @canonicalize_selection_op_scalar_type(%cond: i1) -> () {
  %0 = spv.constant 0: i32
  // CHECK: %[[TRUE_VALUE:.*]] = spv.constant 1 : i32
  %1 = spv.constant 1: i32
  // CHECK: %[[FALSE_VALUE:.*]] = spv.constant 2 : i32
  %2 = spv.constant 2: i32
  // CHECK: %[[DST_VAR:.*]] = spv.Variable init({{%.*}}) : !spv.ptr<i32, Function>
  %3 = spv.Variable init(%0) : !spv.ptr<i32, Function>

  // CHECK: %[[SRC_VALUE:.*]] = spv.Select {{%.*}}, %[[TRUE_VALUE]], %[[FALSE_VALUE]] : i1, i32
  // CHECK-NEXT: spv.Store "Function" %[[DST_VAR]], %[[SRC_VALUE]] ["Aligned", 4] : i32
  // CHECK-NEXT: spv.Return
  spv.selection {
    spv.BranchConditional %cond, ^then, ^else

  ^else:
    spv.Store "Function" %3, %2 ["Aligned", 4]: i32
    spv.Branch ^merge

  ^then:
    spv.Store "Function" %3, %1 ["Aligned", 4]: i32
    spv.Branch ^merge

  ^merge:
    spv._merge
  }
  spv.Return
}

// -----

func @canonicalize_selection_op_vector_type(%cond: i1) -> () {
  %0 = spv.constant dense<[0, 1, 2]> : vector<3xi32>
  // CHECK: %[[TRUE_VALUE:.*]] = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  %1 = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  // CHECK: %[[FALSE_VALUE:.*]] = spv.constant dense<[2, 3, 4]> : vector<3xi32>
  %2 = spv.constant dense<[2, 3, 4]> : vector<3xi32>
  // CHECK: %[[DST_VAR:.*]] = spv.Variable init({{%.*}}) : !spv.ptr<vector<3xi32>, Function>
  %3 = spv.Variable init(%0) : !spv.ptr<vector<3xi32>, Function>

  // CHECK: %[[SRC_VALUE:.*]] = spv.Select {{%.*}}, %[[TRUE_VALUE]], %[[FALSE_VALUE]] : i1, vector<3xi32>
  // CHECK-NEXT: spv.Store "Function" %[[DST_VAR]], %[[SRC_VALUE]] ["Aligned", 8] : vector<3xi32>
  // CHECK-NEXT: spv.Return
  spv.selection {
    spv.BranchConditional %cond, ^then, ^else

  ^then:
    spv.Store "Function" %3, %1 ["Aligned", 8]:  vector<3xi32>
    spv.Branch ^merge

  ^else:
    spv.Store "Function" %3, %2 ["Aligned", 8] : vector<3xi32>
    spv.Branch ^merge

  ^merge:
    spv._merge
  }
  spv.Return
}

// -----

// Store to a different variables.
func @cannot_canonicalize_selection_op_0(%cond: i1) -> () {
  %0 = spv.constant dense<[0, 1, 2]> : vector<3xi32>
  // CHECK: %[[SRC_VALUE_0:.*]] = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  %1 = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  // CHECK: %[[SRC_VALUE_1:.*]] = spv.constant dense<[2, 3, 4]> : vector<3xi32>
  %2 = spv.constant dense<[2, 3, 4]> : vector<3xi32>
  // CHECK: %[[DST_VAR_0:.*]] = spv.Variable init({{%.*}}) : !spv.ptr<vector<3xi32>, Function>
  %3 = spv.Variable init(%0) : !spv.ptr<vector<3xi32>, Function>
  // CHECK: %[[DST_VAR_1:.*]] = spv.Variable init({{%.*}}) : !spv.ptr<vector<3xi32>, Function>
  %4 = spv.Variable init(%0) : !spv.ptr<vector<3xi32>, Function>

  // CHECK: spv.selection {
  spv.selection {
    spv.BranchConditional %cond, ^then, ^else

  ^then:
    // CHECK: spv.Store "Function" %[[DST_VAR_0]], %[[SRC_VALUE_0]] ["Aligned", 8] : vector<3xi32>
    spv.Store "Function" %3, %1 ["Aligned", 8]:  vector<3xi32>
    spv.Branch ^merge

  ^else:
    // CHECK: spv.Store "Function" %[[DST_VAR_1]], %[[SRC_VALUE_1]] ["Aligned", 8] : vector<3xi32>
    spv.Store "Function" %4, %2 ["Aligned", 8] : vector<3xi32>
    spv.Branch ^merge

  ^merge:
    spv._merge
  }
  spv.Return
}

// -----

// A conditional block consists of more than 2 operations.
func @cannot_canonicalize_selection_op_1(%cond: i1) -> () {
  %0 = spv.constant dense<[0, 1, 2]> : vector<3xi32>
  // CHECK: %[[SRC_VALUE_0:.*]] = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  %1 = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  // CHECK: %[[SRC_VALUE_1:.*]] = spv.constant dense<[2, 3, 4]> : vector<3xi32>
  %2 = spv.constant dense<[2, 3, 4]> : vector<3xi32>
  // CHECK: %[[DST_VAR_0:.*]] = spv.Variable init({{%.*}}) : !spv.ptr<vector<3xi32>, Function>
  %3 = spv.Variable init(%0) : !spv.ptr<vector<3xi32>, Function>
  // CHECK: %[[DST_VAR_1:.*]] = spv.Variable init({{%.*}}) : !spv.ptr<vector<3xi32>, Function>
  %4 = spv.Variable init(%0) : !spv.ptr<vector<3xi32>, Function>

  // CHECK: spv.selection {
  spv.selection {
    spv.BranchConditional %cond, ^then, ^else

  ^then:
    // CHECK: spv.Store "Function" %[[DST_VAR_0]], %[[SRC_VALUE_0]] ["Aligned", 8] : vector<3xi32>
    spv.Store "Function" %3, %1 ["Aligned", 8] : vector<3xi32>
    // CHECK: spv.Store "Function" %[[DST_VAR_1]], %[[SRC_VALUE_0]] ["Aligned", 8] : vector<3xi32>
    spv.Store "Function" %4, %1 ["Aligned", 8]:  vector<3xi32>
    spv.Branch ^merge

  ^else:
    // CHECK: spv.Store "Function" %[[DST_VAR_1]], %[[SRC_VALUE_1]] ["Aligned", 8] : vector<3xi32>
    spv.Store "Function" %4, %2 ["Aligned", 8] : vector<3xi32>
    spv.Branch ^merge

  ^merge:
    spv._merge
  }
  spv.Return
}

// -----

// A control-flow goes into `^then` block from `^else` block.
func @cannot_canonicalize_selection_op_2(%cond: i1) -> () {
  %0 = spv.constant dense<[0, 1, 2]> : vector<3xi32>
  // CHECK: %[[SRC_VALUE_0:.*]] = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  %1 = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  // CHECK: %[[SRC_VALUE_1:.*]] = spv.constant dense<[2, 3, 4]> : vector<3xi32>
  %2 = spv.constant dense<[2, 3, 4]> : vector<3xi32>
  // CHECK: %[[DST_VAR:.*]] = spv.Variable init({{%.*}}) : !spv.ptr<vector<3xi32>, Function>
  %3 = spv.Variable init(%0) : !spv.ptr<vector<3xi32>, Function>

  // CHECK: spv.selection {
  spv.selection {
    spv.BranchConditional %cond, ^then, ^else

  ^then:
    // CHECK: spv.Store "Function" %[[DST_VAR]], %[[SRC_VALUE_0]] ["Aligned", 8] : vector<3xi32>
    spv.Store "Function" %3, %1 ["Aligned", 8]:  vector<3xi32>
    spv.Branch ^merge

  ^else:
    // CHECK: spv.Store "Function" %[[DST_VAR]], %[[SRC_VALUE_1]] ["Aligned", 8] : vector<3xi32>
    spv.Store "Function" %3, %2 ["Aligned", 8] : vector<3xi32>
    spv.Branch ^then

  ^merge:
    spv._merge
  }
  spv.Return
}

// -----

// `spv.Return` as a block terminator.
func @cannot_canonicalize_selection_op_3(%cond: i1) -> () {
  %0 = spv.constant dense<[0, 1, 2]> : vector<3xi32>
  // CHECK: %[[SRC_VALUE_0:.*]] = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  %1 = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  // CHECK: %[[SRC_VALUE_1:.*]] = spv.constant dense<[2, 3, 4]> : vector<3xi32>
  %2 = spv.constant dense<[2, 3, 4]> : vector<3xi32>
  // CHECK: %[[DST_VAR:.*]] = spv.Variable init({{%.*}}) : !spv.ptr<vector<3xi32>, Function>
  %3 = spv.Variable init(%0) : !spv.ptr<vector<3xi32>, Function>

  // CHECK: spv.selection {
  spv.selection {
    spv.BranchConditional %cond, ^then, ^else

  ^then:
    // CHECK: spv.Store "Function" %[[DST_VAR]], %[[SRC_VALUE_0]] ["Aligned", 8] : vector<3xi32>
    spv.Store "Function" %3, %1 ["Aligned", 8]:  vector<3xi32>
    spv.Return

  ^else:
    // CHECK: spv.Store "Function" %[[DST_VAR]], %[[SRC_VALUE_1]] ["Aligned", 8] : vector<3xi32>
    spv.Store "Function" %3, %2 ["Aligned", 8] : vector<3xi32>
    spv.Branch ^merge

  ^merge:
    spv._merge
  }
  spv.Return
}

// -----

// Different memory access attributes.
func @cannot_canonicalize_selection_op_4(%cond: i1) -> () {
  %0 = spv.constant dense<[0, 1, 2]> : vector<3xi32>
  // CHECK: %[[SRC_VALUE_0:.*]] = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  %1 = spv.constant dense<[1, 2, 3]> : vector<3xi32>
  // CHECK: %[[SRC_VALUE_1:.*]] = spv.constant dense<[2, 3, 4]> : vector<3xi32>
  %2 = spv.constant dense<[2, 3, 4]> : vector<3xi32>
  // CHECK: %[[DST_VAR:.*]] = spv.Variable init({{%.*}}) : !spv.ptr<vector<3xi32>, Function>
  %3 = spv.Variable init(%0) : !spv.ptr<vector<3xi32>, Function>

  // CHECK: spv.selection {
  spv.selection {
    spv.BranchConditional %cond, ^then, ^else

  ^then:
    // CHECK: spv.Store "Function" %[[DST_VAR]], %[[SRC_VALUE_0]] ["Aligned", 4] : vector<3xi32>
    spv.Store "Function" %3, %1 ["Aligned", 4]:  vector<3xi32>
    spv.Branch ^merge

  ^else:
    // CHECK: spv.Store "Function" %[[DST_VAR]], %[[SRC_VALUE_1]] ["Aligned", 8] : vector<3xi32>
    spv.Store "Function" %3, %2 ["Aligned", 8] : vector<3xi32>
    spv.Branch ^merge

  ^merge:
    spv._merge
  }
  spv.Return
}
