# Theory Audit

Date: 2026-06-09

## Theoretical Scope

The manuscript makes theoretical statements only for:

- the von Mises kernel on `S^1`;
- product von Mises kernels on finite tori `T^d`;
- the von Mises times Gaussian kernel on `S^1 x R^p`;
- population HSIC with characteristic product kernels.

Spherical and hyperspherical settings are mentioned only as future work.

## Circle

The von Mises kernel is

`k_kappa(theta, theta') = exp{kappa cos(theta - theta')}`, with `kappa > 0`.

The proof uses the Fourier-Bessel expansion with modified Bessel coefficients `I_m(kappa)`. The manuscript now cites Abramowitz and Stegun for the special-functions facts used in the expansion and strict positivity.

The characteristicness proof sets `nu = P - Q`, where `P` and `Q` are Borel probability measures and `nu` is a finite signed Borel measure. It then uses

`MMD^2 = sum_m I_m(kappa) |nu_hat_m|^2`.

Strict positivity of every coefficient implies all Fourier coefficients of `nu` vanish. Uniqueness of finite Borel measures from Fourier coefficients on compact Abelian groups is cited through Rudin and the RKHS group-kernel literature.

## Torus

The toroidal product kernel is stated with all concentration parameters strictly positive:

`K_kappa(x,x') = exp{sum_r kappa_r cos(theta_r - theta'_r)}`.

The multi-index Fourier coefficients are products of `I_m(kappa_r)`, hence strictly positive for every multi-index when every `kappa_r > 0`. The proof explicitly notes that positivity in every coordinate is needed because a zero concentration makes the kernel constant in that coordinate.

## Circular-Linear

The circular-linear proposition is limited to the practical von Mises times Gaussian product kernel. The proof views `S^1 x R^p` as a locally compact Abelian group with dual `Z x R^p`. The von Mises factor has strictly positive Fourier coefficients and the Gaussian factor has strictly positive spectral density on all of `R^p`; therefore the product spectral support is the full dual group.

The manuscript cites harmonic-analysis and kernel-embedding references for this Fourier characterization.

## Permutation Theory

The empirical section distinguishes full permutation enumeration from Monte Carlo permutation sampling. It cites Phipson and Smyth for add-one Monte Carlo permutation p-values and states that ordinary permutation calibration relies on i.i.d. pairs or exchangeability under the null.

## Remaining Risks

- A theoretical reviewer may ask for more detail on Fourier uniqueness on compact groups.
- The circular-linear statement is intentionally limited to the Gaussian Euclidean factor.
- The paper does not prove a general product theorem for arbitrary non-compact spaces.
