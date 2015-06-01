(define (walk u s)
  ;; Walking a variable or term in a substitution will
  ;; give either the value it points to, or a fresh variable
  ;;
  ;; it is sort of like `weak-head normal form`
  (if (var? u)
      (let-values (((v? v) (substitution-get (var->int u) s)))
	(if v?
	    (walk v s)
	    u))
      u))

(define (walk* v s)
  ;; walk* recursively walks a term to put it into a
  ;; normalized/completely evaluated form
  (let ((v (walk v s)))
    (cond
     ((var? v) v)
     ((pair? v) (cons (walk* (car v) s)
                      (walk* (cdr v) s)))
     ((record? v) => (lambda (n/c/d)
		       (let ((constructor (cadr n/c/d))
			     (destructor (caddr n/c/d)))
			 (apply constructor (map (lambda (v) (walk* v s))
						 (destructor v))))))
     (else v))))

(define (occurs-check x v s)
  ;; Performing occurs check of a variable in a term
  ;; given a substitution.
  ;; This lets us fail on cyclic/unfounded unifications
  (let ((v (walk v s)))
    (cond
     ((var? v) (var=? v x))
     ((pair? v) (or (occurs-check x (car v) s)
                    (occurs-check x (cdr v) s)))
     ((record? v) => (lambda (n/c/d)
		       (let ((destructor (caddr n/c/d)))
			 (any (lambda (v) (occurs-check x v s))
			      (destructor v)))))
     (else #f))))

(define (extend-substitution/prefix x v s p)
  (if (occurs-check x v s)
      (values #f
              #f)
      (values (substitution-set (var->int x) v s)
              `((,x . ,v) . ,p))))

(define (unify u v s)
  (let-values (((s p) (unify/prefix u v s))) s))

(define (unify/prefix u v s) (unify/prefix* u v s '()))

(define (unify/prefix* u v s p)
  ;; This version of unification builds up a `prefix`
  ;; which contains all the variables that were involved
  ;; in unification that are no longer fresh
  ;;
  ;; This is not needed for pure minikanren but it is
  ;; useful for implementing constraints.
  (let ((u (walk u s)) (v (walk v s)))
    (cond
     ((and (var? u) (var? v) (var=? u v)) (values s p))
     ((var? u) (extend-substitution/prefix u v s p))
     ((var? v) (extend-substitution/prefix v u s p))
     ((and (pair? u) (pair? v))
      (let-values (((s p) (unify/prefix* (car u) (car v) s p)))
	(if s
            (unify/prefix* (cdr u) (cdr v) s p)
            (values #f #f))))
     ((let ((ru (record? u)) (rv (record? v)))
	(and (eq? ru rv) ru rv)) => (lambda (n/c/d)
				      (let ((constructor (cadr n/c/d))
					    (destructor (caddr n/c/d)))
					(unify/prefix* (destructor u)
						       (destructor v)
						       s
						       p))))
     (else (if (eqv? u v)
               (values s p)
               (values #f #f))))))
