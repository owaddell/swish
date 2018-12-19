(import
 (page-utils helpers)
 (text-utils describe))

(define (guess n)
  `(p ,(format "There may be ~a star~p." (describe n) n)))

(simple-page op "Stars"
  `(body
    ,@(map guess (iota 10))
    ,(guess (expt 10 21))
    ,(guess 'again)))
