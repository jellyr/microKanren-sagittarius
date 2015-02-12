;; relational scheme interpreter
;; (currently without symbolo or absento)

(define lookupo
  (lambda (x env out)
    (fresh (y val env^)
      (== `((,y . ,val) . ,env^) env)
      ;(symbolo x)
      ;(symbolo y)
      (conde
        ((== x y) (== val out))
        ((=/= x y) (lookupo x env^ out))))))


(define unboundo
  (lambda (x env)
    (fresh ()
      ;(symbolo x)
      (conde
        ((== '() env))
        ((fresh (y v env^)
           (== `((,y . ,v) . ,env^) env)
           (=/= x y)
           (unboundo x env^)))))))


(define eval-expo
  (lambda (expr env out)
    (fresh ()
      (conde
        (;(symbolo expr) ;; variable
         (lookupo expr env out))
        ((== `(quote ,out) expr)
         ;(absento 'closure out)
         (unboundo 'quote env))
        ((fresh (e1 e2 v1 v2)
           (== `(cons ,e1 ,e2) expr)
           (== `(,v1 . ,v2) out)
           (unboundo 'cons env)
           (eval-expo e1 env v1)
           (eval-expo e2 env v2)))
        ((fresh (e v2)
           (== `(car ,e) expr)
           (unboundo 'car env)
           (eval-expo e env `(,out . ,v2))))
        ((fresh (e v1)
           (== `(cdr ,e) expr)
           (unboundo 'cdr env)
           (eval-expo e env `(,v1 . ,out))))
        ((fresh (e v)
           (== `(null? ,e) expr)
           (conde
             ((== '() v) (== #t out))
             ((=/= '() v) (== #f out)))
           (unboundo 'null? env)
           (eval-expo e env v)))
        ((fresh (t c a b)
           (== `(if ,t ,c ,a) expr)
           (unboundo 'if env)
           (eval-expo t env b)
           (conde
             ((== #f b) (eval-expo a env out))
             ((=/= #f b) (eval-expo c env out)))))
        ((fresh (expr*)
           (== `(list . ,expr*) expr)
           (unboundo 'list env)
           (eval-exp*o expr* env out)))
        ((fresh (x body) ;; abstraction
           (== `(lambda (,x) ,body) expr)
           (== `(closure ,x ,body ,env) out)
           ;;(symbolo x)
           (unboundo 'lambda env)))
        ((fresh (e1 e2 val x body env^) ;; application
           (== `(,e1 ,e2) expr)
           (eval-expo e1 env `(closure ,x ,body ,env^))
           (eval-expo e2 env val)
           (eval-expo body `((,x . ,val) . ,env^) out)))))))

(define eval-exp*o
  (lambda (expr* env out)
    (conde
      ((== '() expr*) (== '() out))
      ((fresh (a d res-a res-d)
         (== (cons a d) expr*)
         (== (cons res-a res-d) out)
         (eval-expo a env res-a)
         (eval-exp*o d env res-d))))))


;; running append in reverse
(display (run* (lambda (q)
  (fresh (x y)
      (== q `(,x ,y))
      (eval-expo `((((lambda (f)
                 ((lambda (x)
                    (f (x x)))
                  (lambda (x)
                    (lambda (y) ((f (x x)) y)))))
               (lambda (my-append)
                 (lambda (l)
                   (lambda (s)
                     (if (null? l)
                         s
                         (cons (car l) ((my-append (cdr l)) s)))))))
              (quote ,x))
             (quote ,y)) '() '(a b c d e))))))
