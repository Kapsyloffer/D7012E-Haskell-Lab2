-- Code to Haskell lab assignment 2 in the course D7012E by Håkan Jonsson

import Data.Char

data EXPR = Const Int
     | Var String
     | Op String EXPR EXPR
     | App String EXPR deriving (Eq, Ord, Show)

parse :: String -> EXPR
parse = fst . buildexpr
  where
    notfirst p (_,[]) = True
    notfirst p (_,x:xs) = not (p x)
    
    buildnumber :: String -> (EXPR,String)
    buildnumber xs = until (notfirst isDigit) accdigits (Const 0, xs)
      where
        accdigits :: (EXPR,String) -> (EXPR,String)
        accdigits (Const n, y:ys) = (Const(10*n+(ord y - 48)), ys)
    
    buildvar :: String -> (EXPR,String)
    buildvar xs = until (notfirst isLetter) accletters (Var "", xs)
      where
        accletters :: (EXPR,String) -> (EXPR,String)
        accletters (Var s, y:ys) = (Var (s ++[y]), ys)
    
    
    buildexpr :: String -> (EXPR,String)
    buildexpr xs = until (notfirst (\c -> c=='-' || c=='+')) accterms (buildterm xs)
      where
        accterms :: (EXPR,String) -> (EXPR,String)
        accterms (term, y:ys) = (Op (y:[]) term term1, zs)
          where
            (term1,zs) = buildterm ys
    
    buildterm :: String -> (EXPR,String)
    buildterm xs = until (notfirst (\c -> c=='*' || c=='/')) accfactors (buildfactor xs)
      where
        accfactors :: (EXPR,String) -> (EXPR,String)  
        accfactors (fact, y:ys) = (Op (y:[]) fact fact1, zs)
          where
            (fact1,zs) = buildfactor ys
    
    buildfactor :: String -> (EXPR,String)
    buildfactor [] = error "missing factor"
    buildfactor ('(':xs) =  case buildexpr xs of (e, ')':ws) -> (e, ws); _ -> error "missing factor"
    buildfactor (x:xs)
      | isDigit x = buildnumber (x:xs)
      | isLetter x = case buildvar (x:xs) of
                       (Var s, '(':zs) -> let (e,ws)=buildfactor ('(':zs) in (App s e,ws)
                       p -> p
      | otherwise = error "illegal symbol"

unparse :: EXPR -> String
unparse (Const n) = show n
unparse (Var s) = s
unparse (Op oper e1 e2) = "(" ++ unparse e1 ++ oper ++ unparse e2 ++ ")"
--task1
unparse (App fn e) = fn ++ "(" ++ unparse e ++ ")"


eval :: EXPR -> [(String,Float)] -> Float
eval (Const n) _ = fromIntegral n
eval (Var x) env = case lookup x env of Just y -> y ; _ -> error (x ++ " undefined")
eval (Op "+" left right) env = eval left env + eval right env
eval (Op "-" left right) env = eval left env - eval right env
eval (Op "*" left right) env = eval left env * eval right env
eval (Op "/" left right) env = eval left env / eval right env
--task1
eval (App "sin" x) env = sin (eval x env) 
eval (App "cos" x) env = cos (eval x env)
eval (App "log" x) env = log (eval x env)
eval (App "exp" x) env = exp (eval x env)

diff :: EXPR -> EXPR -> EXPR
diff _ (Const _) = Const 0
diff (Var id) (Var id2)
  | id == id2 = Const 1
  | otherwise = Const 0
diff v (Op "+" e1 e2) = Op "+" (diff v e1) (diff v e2)
diff v (Op "-" e1 e2) = Op "-" (diff v e1) (diff v e2)
diff v (Op "*" e1 e2) =
  Op "+" (Op "*" (diff v e1) e2) (Op "*" e1 (diff v e2))
diff v (Op "/" e1 e2) =
  Op "/" (Op "-" (Op "*" (diff v e1) e1) (Op "*" e1 (diff v e2))) (Op "*" e2 e2)
diff v (App "sin" x) = Op "*" (diff v x) (App "cos" (x))
diff v (App "cos" x) = Op "*" (simplify (Op "-" (Const 0) (diff v x))) (App "sin" (x))
diff v (App "log" x) = Op "/" (diff v x) x
diff v (App "exp" x) = Op "*" (diff v x) (App "exp" (x))
diff _ _ = error "can not compute the derivative"

simplify :: EXPR -> EXPR
simplify (Const n) = Const n
simplify (Var id) = Var id
simplify (App fn x) = App fn (simplify x) --task1
simplify (Op oper left right) =
  let (lefts,rights) = (simplify left, simplify right) in
    case (oper, lefts, rights) of
      ("+",e,Const 0) -> e
      ("+",Const 0,e) -> e
      ("*",e,Const 0) -> Const 0
      ("*",Const 0,e) -> Const 0
      ("*",e,Const 1) -> e
      ("*",Const 1,e) -> e
      ("-",e,Const 0) -> e
      ("/",e,Const 1) -> e
      ("-",le,re)     -> if left==right then Const 0 else Op "-" le re
      (op,le,re)      -> Op op le re

--task2

mkfun :: (EXPR, EXPR) -> (Float -> Float)
mkfun (body, Var v) = (\x -> eval body [(v, x)])
mkfun (_, _) = error ""


--task3

newtonraphson :: (Float -> Float) -> (Float -> Float) -> Float -> Float
newtonraphson f f' x
  | abs (x - next) < 0.0001 = x
  | otherwise = newtonraphson f f' next
  where
    next = x - (f x) / (f' x)

findzero :: String -> String -> Float -> Float
findzero var body x = newtonraphson (mkfun (f, v)) (mkfun ((diff v f), v)) x
  where
    f = parse body
    v = parse var


main = do
  print(parse "15+x") --funkar
  
  -- Task 1
  print(unparse (simplify (diff (Var "x") (parse "exp(cos(2*x))")))) --funkar

  -- Task 2
  print $ mkfun (parse "x*x+2", Var "x") 1.0 --funkar (ska bli 3)
  print $ mkfun (parse "x*x+2", Var "x") 2.0 --funkar (ska bli 6)
  print $ mkfun (parse "x*x+2", Var "x") 3.0 --funkar (ska bli 11)

  -- Task 3
  print $ findzero "x" "x*x*x+x-1" 1.0            -- 0.6823278 (funkar)
  print $ findzero "y" "cos(y)*sin(y)" 2.0        -- 1.5707964 (funkar)
  print $ findzero "z" "sin(z)+cos(z)-log(z)" 3.0