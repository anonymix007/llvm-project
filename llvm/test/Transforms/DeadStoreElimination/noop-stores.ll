; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt < %s -basic-aa -dse -S | FileCheck %s
; RUN: opt < %s -aa-pipeline=basic-aa -passes='dse,verify<memoryssa>' -S | FileCheck %s
target datalayout = "E-p:64:64:64-a0:0:8-f32:32:32-f64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-v64:64:64-v128:128:128"

declare void @memset_pattern16(i8*, i8*, i64)

declare void @llvm.memset.p0i8.i64(i8* nocapture, i8, i64, i1) nounwind
declare void @llvm.memset.element.unordered.atomic.p0i8.i64(i8* nocapture, i8, i64, i32) nounwind
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* nocapture, i8* nocapture, i64, i1) nounwind
declare void @llvm.memcpy.element.unordered.atomic.p0i8.p0i8.i64(i8* nocapture, i8* nocapture, i64, i32) nounwind
declare void @llvm.init.trampoline(i8*, i8*, i8*)

; **** Noop load->store tests **************************************************

; We CAN optimize volatile loads.
define void @test_load_volatile(i32* %Q) {
; CHECK-LABEL: @test_load_volatile(
; CHECK-NEXT:    [[A:%.*]] = load volatile i32, i32* [[Q:%.*]], align 4
; CHECK-NEXT:    ret void
;
  %a = load volatile i32, i32* %Q
  store i32 %a, i32* %Q
  ret void
}

; We can NOT optimize volatile stores.
define void @test_store_volatile(i32* %Q) {
; CHECK-LABEL: @test_store_volatile(
; CHECK-NEXT:    [[A:%.*]] = load i32, i32* [[Q:%.*]], align 4
; CHECK-NEXT:    store volatile i32 [[A]], i32* [[Q]], align 4
; CHECK-NEXT:    ret void
;
  %a = load i32, i32* %Q
  store volatile i32 %a, i32* %Q
  ret void
}

; PR2599 - load -> store to same address.
define void @test12({ i32, i32 }* %x) nounwind  {
; CHECK-LABEL: @test12(
; CHECK-NEXT:    [[TEMP7:%.*]] = getelementptr { i32, i32 }, { i32, i32 }* [[X:%.*]], i32 0, i32 1
; CHECK-NEXT:    [[TEMP8:%.*]] = load i32, i32* [[TEMP7]], align 4
; CHECK-NEXT:    [[TEMP17:%.*]] = sub i32 0, [[TEMP8]]
; CHECK-NEXT:    store i32 [[TEMP17]], i32* [[TEMP7]], align 4
; CHECK-NEXT:    ret void
;
  %temp4 = getelementptr { i32, i32 }, { i32, i32 }* %x, i32 0, i32 0
  %temp5 = load i32, i32* %temp4, align 4
  %temp7 = getelementptr { i32, i32 }, { i32, i32 }* %x, i32 0, i32 1
  %temp8 = load i32, i32* %temp7, align 4
  %temp17 = sub i32 0, %temp8
  store i32 %temp5, i32* %temp4, align 4
  store i32 %temp17, i32* %temp7, align 4
  ret void
}

; Remove redundant store if loaded value is in another block.
define i32 @test26(i1 %c, i32* %p) {
; CHECK-LABEL: @test26(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[C:%.*]], label [[BB1:%.*]], label [[BB2:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    br label [[BB3:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    br label [[BB3]]
; CHECK:       bb3:
; CHECK-NEXT:    ret i32 0
;
entry:
  %v = load i32, i32* %p, align 4
  br i1 %c, label %bb1, label %bb2
bb1:
  br label %bb3
bb2:
  store i32 %v, i32* %p, align 4
  br label %bb3
bb3:
  ret i32 0
}

; Remove redundant store if loaded value is in another block.
define i32 @test27(i1 %c, i32* %p) {
; CHECK-LABEL: @test27(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[C:%.*]], label [[BB1:%.*]], label [[BB2:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    br label [[BB3:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    br label [[BB3]]
; CHECK:       bb3:
; CHECK-NEXT:    ret i32 0
;
entry:
  %v = load i32, i32* %p, align 4
  br i1 %c, label %bb1, label %bb2
bb1:
  br label %bb3
bb2:
  br label %bb3
bb3:
  store i32 %v, i32* %p, align 4
  ret i32 0
}

; Remove redundant store if loaded value is in another block inside a loop.
define i32 @test31(i1 %c, i32* %p, i32 %i) {
; CHECK-LABEL: @test31(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br label [[BB1:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    br i1 [[C:%.*]], label [[BB1]], label [[BB2:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    ret i32 0
;
entry:
  %v = load i32, i32* %p, align 4
  br label %bb1
bb1:
  store i32 %v, i32* %p, align 4
  br i1 %c, label %bb1, label %bb2
bb2:
  ret i32 0
}

; Don't remove "redundant" store if %p is possibly stored to.
define i32 @test46(i1 %c, i32* %p, i32* %p2, i32 %i) {
; CHECK-LABEL: @test46(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[V:%.*]] = load i32, i32* [[P:%.*]], align 4
; CHECK-NEXT:    br label [[BB1:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    store i32 [[V]], i32* [[P]], align 4
; CHECK-NEXT:    br i1 [[C:%.*]], label [[BB1]], label [[BB2:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    store i32 0, i32* [[P2:%.*]], align 4
; CHECK-NEXT:    br i1 [[C]], label [[BB3:%.*]], label [[BB1]]
; CHECK:       bb3:
; CHECK-NEXT:    ret i32 0
;
entry:
  %v = load i32, i32* %p, align 4
  br label %bb1
bb1:
  store i32 %v, i32* %p, align 4
  br i1 %c, label %bb1, label %bb2
bb2:
  store i32 0, i32* %p2, align 4
  br i1 %c, label %bb3, label %bb1
bb3:
  ret i32 0
}

declare void @unknown_func()

; Remove redundant store, which is in the lame loop as the load.
define i32 @test33(i1 %c, i32* %p, i32 %i) {
; CHECK-LABEL: @test33(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br label [[BB1:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    br label [[BB2:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    call void @unknown_func()
; CHECK-NEXT:    br i1 [[C:%.*]], label [[BB1]], label [[BB3:%.*]]
; CHECK:       bb3:
; CHECK-NEXT:    ret i32 0
;
entry:
  br label %bb1
bb1:
  %v = load i32, i32* %p, align 4
  br label %bb2
bb2:
  store i32 %v, i32* %p, align 4
  ; Might read and overwrite value at %p, but doesn't matter.
  call void @unknown_func()
  br i1 %c, label %bb1, label %bb3
bb3:
  ret i32 0
}

declare void @unkown_write(i32*)

; We can't remove the "noop" store around an unkown write.
define void @test43(i32* %Q) {
; CHECK-LABEL: @test43(
; CHECK-NEXT:    [[A:%.*]] = load i32, i32* [[Q:%.*]], align 4
; CHECK-NEXT:    call void @unkown_write(i32* [[Q]])
; CHECK-NEXT:    store i32 [[A]], i32* [[Q]], align 4
; CHECK-NEXT:    ret void
;
  %a = load i32, i32* %Q
  call void @unkown_write(i32* %Q)
  store i32 %a, i32* %Q
  ret void
}

; We CAN remove it when the unkown write comes AFTER.
define void @test44(i32* %Q) {
; CHECK-LABEL: @test44(
; CHECK-NEXT:    call void @unkown_write(i32* [[Q:%.*]])
; CHECK-NEXT:    ret void
;
  %a = load i32, i32* %Q
  store i32 %a, i32* %Q
  call void @unkown_write(i32* %Q)
  ret void
}

define void @test45(i32* %Q) {
; CHECK-LABEL: @test45(
; CHECK-NEXT:    ret void
;
  %a = load i32, i32* %Q
  store i32 10, i32* %Q
  store i32 %a, i32* %Q
  ret void
}

define i32 @test48(i1 %c, i32* %p) {
; CHECK-LABEL: @test48(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[V:%.*]] = load i32, i32* [[P:%.*]], align 4
; CHECK-NEXT:    br i1 [[C:%.*]], label [[BB0:%.*]], label [[BB0_0:%.*]]
; CHECK:       bb0:
; CHECK-NEXT:    store i32 0, i32* [[P]], align 4
; CHECK-NEXT:    br i1 [[C]], label [[BB1:%.*]], label [[BB2:%.*]]
; CHECK:       bb0.0:
; CHECK-NEXT:    br label [[BB1]]
; CHECK:       bb1:
; CHECK-NEXT:    store i32 [[V]], i32* [[P]], align 4
; CHECK-NEXT:    br i1 [[C]], label [[BB2]], label [[BB0]]
; CHECK:       bb2:
; CHECK-NEXT:    ret i32 0
;
entry:
  %v = load i32, i32* %p, align 4
  br i1 %c, label %bb0, label %bb0.0

bb0:
  store i32 0, i32* %p
  br i1 %c, label %bb1, label %bb2

bb0.0:
  br label %bb1

bb1:
  store i32 %v, i32* %p, align 4
  br i1 %c, label %bb2, label %bb0
bb2:
  ret i32 0
}

define i32 @test47(i1 %c, i32* %p, i32 %i) {
; CHECK-LABEL: @test47(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br label [[BB1:%.*]]
; CHECK:       bb1:
; CHECK-NEXT:    br i1 [[C:%.*]], label [[BB1]], label [[BB2:%.*]]
; CHECK:       bb2:
; CHECK-NEXT:    br i1 [[C]], label [[BB3:%.*]], label [[BB1]]
; CHECK:       bb3:
; CHECK-NEXT:    ret i32 0
;
entry:
  %v = load i32, i32* %p, align 4
  br label %bb1
bb1:
  store i32 %v, i32* %p, align 4
  br i1 %c, label %bb1, label %bb2
bb2:
  store i32 %v, i32* %p, align 4
  br i1 %c, label %bb3, label %bb1
bb3:
  ret i32 0
}

; Test case from PR47887.
define void @test_noalias_store_between_load_and_store(i32* noalias %x, i32* noalias %y) {
; CHECK-LABEL: @test_noalias_store_between_load_and_store(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    store i32 0, i32* [[Y:%.*]], align 4
; CHECK-NEXT:    ret void
;
entry:
  %lv = load i32, i32* %x, align 4
  store i32 0, i32* %y, align 4
  store i32 %lv, i32* %x, align 4
  ret void
}

; Test case from PR47887. Currently we eliminate the dead `store i32 %inc, i32* %x`,
; but not the no-op `store i32 %lv, i32* %x`. That is because no-op stores are
; eliminated before dead stores for the same def.
define void @test_noalias_store_between_load_and_store_elimin_order(i32* noalias %x, i32* noalias %y) {
; CHECK-LABEL: @test_noalias_store_between_load_and_store_elimin_order(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    store i32 0, i32* [[Y:%.*]], align 4
; CHECK-NEXT:    ret void
;
entry:
  %lv = load i32, i32* %x, align 4
  %inc = add nsw i32 %lv, 1
  store i32 %inc, i32* %x, align 4
  store i32 0, i32* %y, align 4
  store i32 %lv, i32* %x, align 4
  ret void
}

declare noalias i8* @malloc(i64)
declare noalias i8* @_Znwm(i64)
declare void @clobber_memory(float*)

; based on pr25892_lite
define i8* @zero_memset_after_malloc(i64 %size) {
; CHECK-LABEL: @zero_memset_after_malloc(
; CHECK-NEXT:    [[CALLOC:%.*]] = call i8* @calloc(i64 1, i64 [[SIZE:%.*]])
; CHECK-NEXT:    ret i8* [[CALLOC]]
;
  %call = call i8* @malloc(i64 %size) inaccessiblememonly
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 %size, i1 false)
  ret i8* %call
}

; based on pr25892_lite
define i8* @zero_memset_after_malloc_with_intermediate_clobbering(i64 %size) {
; CHECK-LABEL: @zero_memset_after_malloc_with_intermediate_clobbering(
; CHECK-NEXT:    [[CALL:%.*]] = call i8* @malloc(i64 [[SIZE:%.*]]) #[[ATTR7:[0-9]+]]
; CHECK-NEXT:    [[BC:%.*]] = bitcast i8* [[CALL]] to float*
; CHECK-NEXT:    call void @clobber_memory(float* [[BC]])
; CHECK-NEXT:    call void @llvm.memset.p0i8.i64(i8* [[CALL]], i8 0, i64 [[SIZE]], i1 false)
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = call i8* @malloc(i64 %size) inaccessiblememonly
  %bc = bitcast i8* %call to float*
  call void @clobber_memory(float* %bc)
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 %size, i1 false)
  ret i8* %call
}

; based on pr25892_lite
define i8* @zero_memset_after_malloc_with_different_sizes(i64 %size) {
; CHECK-LABEL: @zero_memset_after_malloc_with_different_sizes(
; CHECK-NEXT:    [[CALL:%.*]] = call i8* @malloc(i64 [[SIZE:%.*]]) #[[ATTR7]]
; CHECK-NEXT:    [[SIZE2:%.*]] = add nsw i64 [[SIZE]], -1
; CHECK-NEXT:    call void @llvm.memset.p0i8.i64(i8* [[CALL]], i8 0, i64 [[SIZE2]], i1 false)
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = call i8* @malloc(i64 %size) inaccessiblememonly
  %size2 = add nsw i64 %size, -1
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 %size2, i1 false)
  ret i8* %call
}

; based on pr25892_lite
define i8* @zero_memset_after_new(i64 %size) {
; CHECK-LABEL: @zero_memset_after_new(
; CHECK-NEXT:    [[CALL:%.*]] = call i8* @_Znwm(i64 [[SIZE:%.*]])
; CHECK-NEXT:    call void @llvm.memset.p0i8.i64(i8* [[CALL]], i8 0, i64 [[SIZE]], i1 false)
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = call i8* @_Znwm(i64 %size)
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 %size, i1 false)
  ret i8* %call
}

; This should not create a calloc and should not crash the compiler.
define i8* @notmalloc_memset(i64 %size, i8*(i64)* %notmalloc) {
; CHECK-LABEL: @notmalloc_memset(
; CHECK-NEXT:    [[CALL1:%.*]] = call i8* [[NOTMALLOC:%.*]](i64 [[SIZE:%.*]])
; CHECK-NEXT:    call void @llvm.memset.p0i8.i64(i8* [[CALL1]], i8 0, i64 [[SIZE]], i1 false)
; CHECK-NEXT:    ret i8* [[CALL1]]
;
  %call1 = call i8* %notmalloc(i64 %size)
  call void @llvm.memset.p0i8.i64(i8* %call1, i8 0, i64 %size, i1 false)
  ret i8* %call1
}

; This should not create recursive call to calloc.
define i8* @calloc(i64 %nmemb, i64 %size) inaccessiblememonly {
; CHECK-LABEL: @calloc(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[MUL:%.*]] = mul i64 [[SIZE:%.*]], [[NMEMB:%.*]]
; CHECK-NEXT:    [[CALL:%.*]] = tail call noalias align 16 i8* @malloc(i64 [[MUL]])
; CHECK-NEXT:    [[TOBOOL_NOT:%.*]] = icmp eq i8* [[CALL]], null
; CHECK-NEXT:    br i1 [[TOBOOL_NOT]], label [[IF_END:%.*]], label [[IF_THEN:%.*]]
; CHECK:       if.then:
; CHECK-NEXT:    tail call void @llvm.memset.p0i8.i64(i8* nonnull align 16 [[CALL]], i8 0, i64 [[MUL]], i1 false)
; CHECK-NEXT:    br label [[IF_END]]
; CHECK:       if.end:
; CHECK-NEXT:    ret i8* [[CALL]]
;
entry:
  %mul = mul i64 %size, %nmemb
  %call = tail call noalias align 16 i8* @malloc(i64 %mul)
  %tobool.not = icmp eq i8* %call, null
  br i1 %tobool.not, label %if.end, label %if.then

if.then:                                          ; preds = %entry
  tail call void @llvm.memset.p0i8.i64(i8* nonnull align 16 %call, i8 0, i64 %mul, i1 false)
  br label %if.end

if.end:                                           ; preds = %if.then, %entry
  ret i8* %call
}

define float* @pr25892(i64 %size) {
; CHECK-LABEL: @pr25892(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CALLOC:%.*]] = call i8* @calloc(i64 1, i64 [[SIZE:%.*]])
; CHECK-NEXT:    [[CMP:%.*]] = icmp eq i8* [[CALLOC]], null
; CHECK-NEXT:    br i1 [[CMP]], label [[CLEANUP:%.*]], label [[IF_END:%.*]]
; CHECK:       if.end:
; CHECK-NEXT:    [[BC:%.*]] = bitcast i8* [[CALLOC]] to float*
; CHECK-NEXT:    br label [[CLEANUP]]
; CHECK:       cleanup:
; CHECK-NEXT:    [[RETVAL_0:%.*]] = phi float* [ [[BC]], [[IF_END]] ], [ null, [[ENTRY:%.*]] ]
; CHECK-NEXT:    ret float* [[RETVAL_0]]
;
entry:
  %call = call i8* @malloc(i64 %size) inaccessiblememonly
  %cmp = icmp eq i8* %call, null
  br i1 %cmp, label %cleanup, label %if.end
if.end:
  %bc = bitcast i8* %call to float*
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 %size, i1 false)
  br label %cleanup
cleanup:
  %retval.0 = phi float* [ %bc, %if.end ], [ null, %entry ]
  ret float* %retval.0
}

define float* @pr25892_with_extra_store(i64 %size) {
; CHECK-LABEL: @pr25892_with_extra_store(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CALLOC:%.*]] = call i8* @calloc(i64 1, i64 [[SIZE:%.*]])
; CHECK-NEXT:    [[CMP:%.*]] = icmp eq i8* [[CALLOC]], null
; CHECK-NEXT:    br i1 [[CMP]], label [[CLEANUP:%.*]], label [[IF_END:%.*]]
; CHECK:       if.end:
; CHECK-NEXT:    [[BC:%.*]] = bitcast i8* [[CALLOC]] to float*
; CHECK-NEXT:    br label [[CLEANUP]]
; CHECK:       cleanup:
; CHECK-NEXT:    [[RETVAL_0:%.*]] = phi float* [ [[BC]], [[IF_END]] ], [ null, [[ENTRY:%.*]] ]
; CHECK-NEXT:    ret float* [[RETVAL_0]]
;
entry:
  %call = call i8* @malloc(i64 %size) inaccessiblememonly
  %cmp = icmp eq i8* %call, null
  br i1 %cmp, label %cleanup, label %if.end
if.end:
  %bc = bitcast i8* %call to float*
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 %size, i1 false)
  store i8 0, i8* %call, align 1
  br label %cleanup
cleanup:
  %retval.0 = phi float* [ %bc, %if.end ], [ null, %entry ]
  ret float* %retval.0
}

; This should not create a calloc
define i8* @malloc_with_no_nointer_null_check(i64 %0, i32 %1) {
; CHECK-LABEL: @malloc_with_no_nointer_null_check(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CALL:%.*]] = call i8* @malloc(i64 [[TMP0:%.*]]) #[[ATTR7]]
; CHECK-NEXT:    [[A:%.*]] = and i32 [[TMP1:%.*]], 32
; CHECK-NEXT:    [[CMP:%.*]] = icmp eq i32 [[A]], 0
; CHECK-NEXT:    br i1 [[CMP]], label [[CLEANUP:%.*]], label [[IF_END:%.*]]
; CHECK:       if.end:
; CHECK-NEXT:    call void @llvm.memset.p0i8.i64(i8* [[CALL]], i8 0, i64 [[TMP0]], i1 false)
; CHECK-NEXT:    br label [[CLEANUP]]
; CHECK:       cleanup:
; CHECK-NEXT:    ret i8* [[CALL]]
;
entry:
  %call = call i8* @malloc(i64 %0) inaccessiblememonly
  %a = and i32 %1, 32
  %cmp = icmp eq i32 %a, 0
  br i1 %cmp, label %cleanup, label %if.end
if.end:
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 %0, i1 false)
  br label %cleanup
cleanup:
  ret i8* %call
}

; PR50143
define i8* @store_zero_after_calloc_inaccessiblememonly() {
; CHECK-LABEL: @store_zero_after_calloc_inaccessiblememonly(
; CHECK-NEXT:    [[CALL:%.*]] = tail call i8* @calloc(i64 1, i64 10) #[[ATTR7]]
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = tail call i8* @calloc(i64 1, i64 10)  inaccessiblememonly
  store i8 0, i8* %call
  ret i8* %call
}

define i8* @zero_memset_after_calloc()  {
; CHECK-LABEL: @zero_memset_after_calloc(
; CHECK-NEXT:    [[CALL:%.*]] = tail call i8* @calloc(i64 10000, i64 4)
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = tail call i8* @calloc(i64 10000, i64 4)
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 40000, i1 false)
  ret i8* %call
}

define i8* @volatile_zero_memset_after_calloc()  {
; CHECK-LABEL: @volatile_zero_memset_after_calloc(
; CHECK-NEXT:    [[CALL:%.*]] = tail call i8* @calloc(i64 10000, i64 4)
; CHECK-NEXT:    call void @llvm.memset.p0i8.i64(i8* [[CALL]], i8 0, i64 40000, i1 true)
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = tail call i8* @calloc(i64 10000, i64 4)
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 40000, i1 true)
  ret i8* %call
}

define i8* @zero_memset_and_store_after_calloc(i8 %v)  {
; CHECK-LABEL: @zero_memset_and_store_after_calloc(
; CHECK-NEXT:    [[CALL:%.*]] = tail call i8* @calloc(i64 10000, i64 4)
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = tail call i8* @calloc(i64 10000, i64 4)
  store i8 %v, i8* %call
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 40000, i1 false)
  ret i8* %call
}

define i8* @partial_zero_memset_after_calloc() {
; CHECK-LABEL: @partial_zero_memset_after_calloc(
; CHECK-NEXT:    [[CALL:%.*]] = tail call i8* @calloc(i64 10000, i64 4)
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = tail call i8* @calloc(i64 10000, i64 4)
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 20, i1 false)
  ret i8* %call
}

define i8* @partial_zero_memset_and_store_after_calloc(i8 %v)  {
; CHECK-LABEL: @partial_zero_memset_and_store_after_calloc(
; CHECK-NEXT:    [[CALL:%.*]] = tail call i8* @calloc(i64 10000, i64 4)
; CHECK-NEXT:    [[GEP:%.*]] = getelementptr inbounds i8, i8* [[CALL]], i64 30
; CHECK-NEXT:    store i8 [[V:%.*]], i8* [[GEP]], align 1
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = tail call i8* @calloc(i64 10000, i64 4)
  %gep = getelementptr inbounds i8, i8* %call, i64 30
  store i8 %v, i8* %gep
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 20, i1 false)
  ret i8* %call
}

define i8* @zero_memset_and_store_with_dyn_index_after_calloc(i8 %v, i64 %idx)  {
; CHECK-LABEL: @zero_memset_and_store_with_dyn_index_after_calloc(
; CHECK-NEXT:    [[CALL:%.*]] = tail call i8* @calloc(i64 10000, i64 4)
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = tail call i8* @calloc(i64 10000, i64 4)
  %gep = getelementptr inbounds i8, i8* %call, i64 %idx
  store i8 %v, i8* %gep
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 40000, i1 false)
  ret i8* %call
}

define i8* @partial_zero_memset_and_store_with_dyn_index_after_calloc(i8 %v, i64 %idx)  {
; CHECK-LABEL: @partial_zero_memset_and_store_with_dyn_index_after_calloc(
; CHECK-NEXT:    [[CALL:%.*]] = tail call i8* @calloc(i64 10000, i64 4)
; CHECK-NEXT:    [[GEP:%.*]] = getelementptr inbounds i8, i8* [[CALL]], i64 [[IDX:%.*]]
; CHECK-NEXT:    store i8 [[V:%.*]], i8* [[GEP]], align 1
; CHECK-NEXT:    call void @llvm.memset.p0i8.i64(i8* [[CALL]], i8 0, i64 20, i1 false)
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = tail call i8* @calloc(i64 10000, i64 4)
  %gep = getelementptr inbounds i8, i8* %call, i64 %idx
  store i8 %v, i8* %gep
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 20, i1 false)
  ret i8* %call
}

define i8* @zero_memset_after_calloc_inaccessiblememonly()  {
; CHECK-LABEL: @zero_memset_after_calloc_inaccessiblememonly(
; CHECK-NEXT:    [[CALL:%.*]] = tail call i8* @calloc(i64 10000, i64 4) #[[ATTR7]]
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = tail call i8* @calloc(i64 10000, i64 4) inaccessiblememonly
  call void @llvm.memset.p0i8.i64(i8* %call, i8 0, i64 40000, i1 false)
  ret i8* %call
}

define i8* @cst_nonzero_memset_after_calloc() {
; CHECK-LABEL: @cst_nonzero_memset_after_calloc(
; CHECK-NEXT:    [[CALL:%.*]] = tail call i8* @calloc(i64 10000, i64 4)
; CHECK-NEXT:    call void @llvm.memset.p0i8.i64(i8* [[CALL]], i8 1, i64 40000, i1 false)
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = tail call i8* @calloc(i64 10000, i64 4)
  call void @llvm.memset.p0i8.i64(i8* %call, i8 1, i64 40000, i1 false)
  ret i8* %call
}

define i8* @nonzero_memset_after_calloc(i8 %v) {
; CHECK-LABEL: @nonzero_memset_after_calloc(
; CHECK-NEXT:    [[CALL:%.*]] = tail call i8* @calloc(i64 10000, i64 4)
; CHECK-NEXT:    call void @llvm.memset.p0i8.i64(i8* [[CALL]], i8 [[V:%.*]], i64 40000, i1 false)
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = tail call i8* @calloc(i64 10000, i64 4)
  call void @llvm.memset.p0i8.i64(i8* %call, i8 %v, i64 40000, i1 false)
  ret i8* %call
}

; PR11896
; The first memset is dead, because calloc provides zero-filled memory.
; TODO: This could be replaced with a call to malloc + memset_pattern16.
define i8* @memset_pattern16_after_calloc(i8* %pat) {
; CHECK-LABEL: @memset_pattern16_after_calloc(
; CHECK-NEXT:    [[CALL:%.*]] = tail call i8* @calloc(i64 10000, i64 4)
; CHECK-NEXT:    call void @memset_pattern16(i8* [[CALL]], i8* [[PAT:%.*]], i64 40000)
; CHECK-NEXT:    ret i8* [[CALL]]
;
  %call = tail call i8* @calloc(i64 10000, i64 4) #1
  call void @llvm.memset.p0i8.i64(i8* align 4 %call, i8 0, i64 40000, i1 false)
  call void @memset_pattern16(i8* %call, i8* %pat, i64 40000) #1
  ret i8* %call
}

@n = global i32 0, align 4
@a = external global i32, align 4
@b = external global i32*, align 8

; GCC calloc-1.c test case should create calloc
define i8* @test_malloc_memset_to_calloc(i64* %0) {
; CHECK-LABEL: @test_malloc_memset_to_calloc(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP1:%.*]] = load i32, i32* @n, align 4
; CHECK-NEXT:    [[TMP2:%.*]] = sext i32 [[TMP1]] to i64
; CHECK-NEXT:    [[CALLOC:%.*]] = call i8* @calloc(i64 1, i64 [[TMP2]])
; CHECK-NEXT:    [[TMP3:%.*]] = load i64, i64* [[TMP0:%.*]], align 8
; CHECK-NEXT:    [[TMP4:%.*]] = add nsw i64 [[TMP3]], 1
; CHECK-NEXT:    store i64 [[TMP4]], i64* [[TMP0]], align 8
; CHECK-NEXT:    [[TMP5:%.*]] = icmp eq i8* [[CALLOC]], null
; CHECK-NEXT:    br i1 [[TMP5]], label [[IF_END:%.*]], label [[IF_THEN:%.*]]
; CHECK:       if.then:
; CHECK-NEXT:    [[TMP6:%.*]] = add nsw i64 [[TMP3]], 2
; CHECK-NEXT:    store i64 [[TMP6]], i64* [[TMP0]], align 8
; CHECK-NEXT:    store i32 2, i32* @a, align 4
; CHECK-NEXT:    [[TMP7:%.*]] = load i32*, i32** @b, align 8
; CHECK-NEXT:    store i32 3, i32* [[TMP7]], align 4
; CHECK-NEXT:    br label [[IF_END]]
; CHECK:       if.end:
; CHECK-NEXT:    ret i8* [[CALLOC]]
;
entry:
  %1 = load i32, i32* @n, align 4
  %2 = sext i32 %1 to i64
  %3 = tail call i8* @malloc(i64 %2) inaccessiblememonly
  %4 = load i64, i64* %0, align 8
  %5 = add nsw i64 %4, 1
  store i64 %5, i64* %0, align 8
  %6 = icmp eq i8* %3, null
  br i1 %6, label %if.end, label %if.then

if.then:
  %7 = add nsw i64 %4, 2
  store i64 %7, i64* %0, align 8
  store i32 2, i32* @a, align 4
  tail call void @llvm.memset.p0i8.i64(i8* align 4 %3, i8 0, i64 %2, i1 false)
  %8 = load i32*, i32** @b, align 8
  store i32 3, i32* %8, align 4
  br label %if.end

if.end:
  ret i8* %3
}

define void @store_same_i32_to_mayalias_loc(i32* %q, i32* %p) {
; CHECK-LABEL: @store_same_i32_to_mayalias_loc(
; CHECK-NEXT:    [[V:%.*]] = load i32, i32* [[P:%.*]], align 4
; CHECK-NEXT:    store i32 [[V]], i32* [[Q:%.*]], align 4
; CHECK-NEXT:    ret void
;
  %v = load i32, i32* %p, align 4
  store i32 %v, i32* %q, align 4
  store i32 %v, i32* %p, align 4
  ret void
}

define void @store_same_i32_to_mayalias_loc_unalign(i32* %q, i32* %p) {
; CHECK-LABEL: @store_same_i32_to_mayalias_loc_unalign(
; CHECK-NEXT:    [[V:%.*]] = load i32, i32* [[P:%.*]], align 1
; CHECK-NEXT:    store i32 [[V]], i32* [[Q:%.*]], align 1
; CHECK-NEXT:    store i32 [[V]], i32* [[P]], align 1
; CHECK-NEXT:    ret void
;
  %v = load i32, i32* %p, align 1
  store i32 %v, i32* %q, align 1
  store i32 %v, i32* %p, align 1
  ret void
}

define void @store_same_i12_to_mayalias_loc(i12* %q, i12* %p) {
; CHECK-LABEL: @store_same_i12_to_mayalias_loc(
; CHECK-NEXT:    [[V:%.*]] = load i12, i12* [[P:%.*]], align 2
; CHECK-NEXT:    store i12 [[V]], i12* [[Q:%.*]], align 2
; CHECK-NEXT:    ret void
;
  %v = load i12, i12* %p, align 2
  store i12 %v, i12* %q, align 2
  store i12 %v, i12* %p, align 2
  ret void
}

define void @store_same_i12_to_mayalias_loc_unalign(i12* %q, i12* %p) {
; CHECK-LABEL: @store_same_i12_to_mayalias_loc_unalign(
; CHECK-NEXT:    [[V:%.*]] = load i12, i12* [[P:%.*]], align 1
; CHECK-NEXT:    store i12 [[V]], i12* [[Q:%.*]], align 1
; CHECK-NEXT:    store i12 [[V]], i12* [[P]], align 1
; CHECK-NEXT:    ret void
;
  %v = load i12, i12* %p, align 1
  store i12 %v, i12* %q, align 1
  store i12 %v, i12* %p, align 1
  ret void
}

define void @store_same_ptr_to_mayalias_loc(i32** %q, i32** %p) {
; CHECK-LABEL: @store_same_ptr_to_mayalias_loc(
; CHECK-NEXT:    [[V:%.*]] = load i32*, i32** [[P:%.*]], align 8
; CHECK-NEXT:    store i32* [[V]], i32** [[Q:%.*]], align 8
; CHECK-NEXT:    ret void
;
  %v = load i32*, i32** %p, align 8
  store i32* %v, i32** %q, align 8
  store i32* %v, i32** %p, align 8
  ret void
}

define void @store_same_scalable_to_mayalias_loc(<vscale x 4 x i32>* %q, <vscale x 4 x i32>* %p) {
; CHECK-LABEL: @store_same_scalable_to_mayalias_loc(
; CHECK-NEXT:    [[V:%.*]] = load <vscale x 4 x i32>, <vscale x 4 x i32>* [[P:%.*]], align 4
; CHECK-NEXT:    store <vscale x 4 x i32> [[V]], <vscale x 4 x i32>* [[Q:%.*]], align 4
; CHECK-NEXT:    store <vscale x 4 x i32> [[V]], <vscale x 4 x i32>* [[P]], align 4
; CHECK-NEXT:    ret void
;
  %v = load <vscale x 4 x i32>, <vscale x 4 x i32>* %p, align 4
  store <vscale x 4 x i32> %v, <vscale x 4 x i32>* %q, align 4
  store <vscale x 4 x i32> %v, <vscale x 4 x i32>* %p, align 4
  ret void
}

define void @store_same_i32_to_mayalias_loc_inconsistent_align(i32* %q, i32* %p) {
; CHECK-LABEL: @store_same_i32_to_mayalias_loc_inconsistent_align(
; CHECK-NEXT:    [[V:%.*]] = load i32, i32* [[P:%.*]], align 2
; CHECK-NEXT:    store i32 [[V]], i32* [[Q:%.*]], align 4
; CHECK-NEXT:    store i32 [[V]], i32* [[P]], align 4
; CHECK-NEXT:    ret void
;
  %v = load i32, i32* %p, align 2
  store i32 %v, i32* %q, align 4
  store i32 %v, i32* %p, align 4
  ret void
}

define void @do_not_crash_on_liveonentrydef(i1 %c, i8* %p, i8* noalias %q) {
; CHECK-LABEL: @do_not_crash_on_liveonentrydef(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[C:%.*]], label [[IF:%.*]], label [[JOIN:%.*]]
; CHECK:       if:
; CHECK-NEXT:    store i8 0, i8* [[Q:%.*]], align 1
; CHECK-NEXT:    br label [[JOIN]]
; CHECK:       join:
; CHECK-NEXT:    [[V:%.*]] = load i8, i8* [[Q]], align 1
; CHECK-NEXT:    store i8 0, i8* [[P:%.*]], align 1
; CHECK-NEXT:    store i8 [[V]], i8* [[Q]], align 1
; CHECK-NEXT:    ret void
;
entry:
  br i1 %c, label %if, label %join

if:
  store i8 0, i8* %q, align 1
  br label %join

join:
  %v = load i8, i8* %q, align 1
  store i8 0, i8* %p, align 1
  store i8 %v, i8* %q, align 1
  ret void
}
