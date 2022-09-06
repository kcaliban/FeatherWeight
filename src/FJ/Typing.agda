open import FJ.Syntax


open import Data.List using (List; []; _∷_)
open import Data.List.Relation.Unary.All using (All)
open import Data.Maybe using (Maybe; just; nothing)
open import Data.Product using (_×_; _,_)
open import Function using (const)
open import Relation.Nullary
  using (¬_; Dec; yes; no)
open import Relation.Binary.PropositionalEquality
  using (_≡_; _≢_; refl; sym; trans; cong; cong₂; subst; resp₂)

module FJ.Typing (CT : ClassTable) where

open import FJ.Lookup (CT)
open import FJ.Subtyping (CT)

-- expression typing

data _⊢*_⦂_ (Γ : VarContext) : List Exp → List Type → Set
data _⊢_⦂_ (Γ : VarContext) : Exp → Type → Set where

  T-Var : ∀ {x}{T}
    → declOf x Γ ≡ just (x ⦂ T)
    → Γ ⊢ Var x ⦂ T

  T-Field : ∀ {e₀}{C₀}{f}{T}
    → Γ ⊢ e₀ ⦂ Ty C₀
    → declOf f (fields C₀) ≡ just (f ⦂ T)
    → Γ ⊢ Field e₀ f ⦂ T

  T-Invk : ∀ {e₀}{C₀}{m}{es}{margs}{T}{Ts}
    → Γ ⊢ e₀ ⦂ Ty C₀
    → mtype m C₀ ≡ just (margs , T)
    → Γ ⊢* es ⦂ Ts
    → Ts <:* bound margs                      -- backwards?
    → Γ ⊢ Meth e₀ m es ⦂ T

  T-New : ∀ {C} {es} {Ts} {flds}
    → fields C ≡ flds
    → Γ ⊢* es ⦂ Ts
    → Ts <:* bound flds                      -- backwards?
    → Γ ⊢ New C es ⦂ Ty C

  T-UCast : ∀ {C D e₀}
    → Γ ⊢ e₀ ⦂ Ty D
    → D <: C
    → Γ ⊢ Cast C e₀ ⦂ Ty C

  T-DCast : ∀ {C D e₀}
    → Γ ⊢ e₀ ⦂ Ty D
    → C <: D
    → C ≢ D
    → Γ ⊢ Cast C e₀ ⦂ Ty C

  T-SCast : ∀ {C D e₀}
    → Γ ⊢ e₀ ⦂ Ty D
    → ¬ (C <: D)
    → ¬ (D <: C)
    → Γ ⊢ Cast C e₀ ⦂ Ty C

-- beat strict positivity
data _⊢*_⦂_ Γ where
  T-Z : Γ ⊢* [] ⦂ []
  T-S : ∀ {e} {es} {T} {Ts} → Γ ⊢ e ⦂ T → Γ ⊢* es ⦂ Ts → Γ ⊢* (e ∷ es) ⦂ (T ∷ Ts)

-- method typing

data _OK-IN_ : MethDecl → Class → Set where

  T-Method : ∀ {m xs C₀ e₀ E₀ C cn D}
    → (xs ▷ ("this" ⦂ Ty C)) ⊢ e₀ ⦂ E₀
    → E₀ <:ᵀ C₀
    → C ≡ Extend cn D
    → (∀ {ds D₀} → mtype m D ≡ just (ds , D₀) → (bound xs ≡ bound ds) × (C₀ ≡ D₀))
    → record { name = m ; args = xs ; ty = C₀ ; body = e₀ } OK-IN C

-- class typing

data _OK : ClassDecl → Set where

  T-Class : ∀ {C cn}{D}{fdecl}{mdecl}
    → C ≡ Extend cn D
    → All (_OK-IN C) (toList mdecl)
    → (class cn fls fdecl mts mdecl) OK