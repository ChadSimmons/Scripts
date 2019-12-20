--Deployments for Packages which have not expired
select A.OfferName [Advertisement], P.Manufacturer, P.Name, P.Version, A.PkgProgram, P.LastRefresh [Package Updated in SCCM]
, A.PresentTime
, Case
    When A.ExpirationTime = A.PresentTime Then '12/31/2199'
	Else A.ExpirationTime
	End as [ExpirationTime]
from vAdvertisement AS A
inner join vPackage AS P on A.PkgID = P.PkgID
where (A.ExpirationTime > GetDate() OR A.PresentTime = A.ExpirationTime)
order by P.Manufacturer, P.Name, P.Version --A.ExpirationTime

--Packages with Deployments which have not expired
select DISTINCT P.Manufacturer, P.Name, P.Version--, A.PkgProgram
, P.LastRefresh [Package Updated in SCCM]
from vAdvertisement AS A
inner join vPackage AS P on A.PkgID = P.PkgID
where (A.ExpirationTime > GetDate() OR A.PresentTime = A.ExpirationTime)
order by P.Manufacturer, P.Name, P.Version --A.ExpirationTime