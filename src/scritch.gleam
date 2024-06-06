// import gleam/io

// pub type CoroutineInput(i) {
//   CoroutineInput(i)
//   PrimeIteration
// }

// pub type CoroutineOutput(o) {
//   CoroutineOutput(o)
//   StopIteration
// }

// pub type Coroutine(i, o) {
//   Coroutine(
//     yield: fn(CoroutineOutput(o), fn(CoroutineInput(i), Coroutine(i, o)) -> Nil) ->
//       Nil,
//     resume: fn(
//       CoroutineInput(i),
//       fn(CoroutineOutput(o), Coroutine(i, o)) -> Nil,
//     ) ->
//       Nil,
//   )
// }

// pub fn build_yield_coroutine(outer_continnuation) {
//   Coroutine(
//     resume: fn(_, _) { panic },
//     yield: fn(
//       ouput: CoroutineOutput(o),
//       inner_continuation: fn(CoroutineInput(i), Coroutine(i, o)) -> Nil,
//     ) {
//       let coroutine = build_resume_coroutine(inner_continuation)
//       outer_continnuation(ouput, coroutine)
//       Nil
//     },
//   )
// }

// pub fn build_resume_coroutine(outer_continnuation) {
//   Coroutine(
//     resume: fn(
//       input: CoroutineInput(i),
//       inner_continuation: fn(CoroutineOutput(o), Coroutine(i, o)) -> Nil,
//     ) {
//       let coroutine = build_yield_coroutine(inner_continuation)
//       outer_continnuation(input, coroutine)
//       Nil
//     },
//     yield: fn(_, _) { panic },
//   )
// }

// pub fn new_coroutine(f: fn(Coroutine(i, o)) -> Nil) -> Coroutine(i, o) {
//   Coroutine(
//     resume: fn(
//       _: CoroutineInput(i),
//       outer_continuation: fn(CoroutineOutput(o), Coroutine(i, o)) -> Nil,
//     ) {
//       let coros =
//         Coroutine(resume: fn(_, _) { panic }, yield: fn(ouput, continuation) {
//           let coroutine = build_resume_coroutine(continuation)
//           outer_continuation(ouput, coroutine)
//         })
//       f(coros)
//       Nil
//     },
//     yield: fn(_, _) { panic },
//   )
// }

// pub fn fib_coro() {
//   let f = fn(coro: Coroutine(Int, Int)) {
//     use first, coro <- coro.yield(CoroutineOutput(1))

//     let assert CoroutineInput(okok) = first
//     use next, coro <- coro.yield(CoroutineOutput(okok))
//   }

//   new_coroutine(f)
// }

// pub fn main() {
//   let coro = fib_coro()

//   use _, coro <- coro.resume(PrimeIteration)
//   use value, _ <- coro.resume(CoroutineInput(5))
//   io.debug(value)

//   use value, _ <- coro.resume(CoroutineInput(55))
//   io.debug(value)

//   use value, _ <- coro.resume(CoroutineInput(250))
//   io.debug(value)

//   Nil
// }
