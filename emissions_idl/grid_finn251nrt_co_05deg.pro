;
; read FINN2.5.1 nrt emissions txt file for 1 day
; grid CO to 0.5x0.5 deg

pro grid_finn251nrt_co_05deg

  args = COMMAND_LINE_ARGS()

  if n_elements(args) ne 2 then begin
    print, 'Usage: idl -e grid_finn251nrt_co_05deg -args <date> <data_folder>'
    print, '<date> format is YYYY-MM-DD'
    return
  endif

  datestr = args[0]
  data_path = args[1]

;date to process
;datestr = YYYY-MM-DD
  parts = Strsplit(datestr,'-',/extract)
  year = Fix(parts[0])
  mm = Fix(parts[1])
  dd = Fix(parts[2])
  print,datestr,year,mm,dd

;create date, time arrays
  jday = Julday(mm,dd,year)
  doy = jday - Julday(1,1,year) + 1

  cal_units='days since 1750-01-01 00:00:00'
  time = jday - Julday(1,1,1750)
  date = year*10000L + mm*100L + dd

  yj_str = String(year,doy,format='(i4,i3.3)')
  ymd_str = String(year,mm,dd,format='(i4,i2.2,i2.2)')
  
  today = bin_date(systime())
  todaystr = String(today[0:2],format='(i4,"/",i2.2,"/",i2.2)')
  sdate_today = String(today[0:2],format='(i4,i2.2,i2.2)')

  ndays = 1
  resol='0.5x0.5'

Rearth = 6.37122e6              ;m
deg_rad = 360./(2*!pi)
rad_deg = 2.*!pi/360.
avog = 6.022e23         ;molecules/mole
s_per_day = 86400.
kg_g = 1.e-3   ;kg/g
mw_num = 1.
  
;--INPUTS---
; read FINN2 txt files
txtfile = data_path + '/FINNv2.5.1_modvrs_nrt_MOZART_'+ymd_str+'.txt'

;--OUTPUTs---
path_new = data_path + '/emis_gridded/'
newfilelab='emissions_finn251_modvrs_nrt'


; set up grid
case resol of 
 '0.5x0.5': begin
  nlat = 360
  nlon = 720
  dlat = 0.5
  dlon = 0.5
  latmin = -90.
  latmax = 90.
  lonmin = 0.
  lonmax = 360.
  lon_grid = findgen(nlon)*dlon+lonmin+0.5*dlon
  lat_grid = findgen(nlat)*dlat+latmin+0.5*dlat
 end
 'f05': begin   ;0.45x0.62
  nlat = 384
  nlon = 576
  dlat = 180./(nlat-1)
  dlon = 360./nlon
  latmin = -90.
  latmax = 90.
  lonmin = 0.
  lonmax = 360.
  lon_grid = findgen(nlon)*dlon+lonmin
  lat_grid = findgen(nlat)*dlat+latmin
 end
'0.9x1.25': begin
  nlat = 192
  nlon = 288
  dlat = 180./(nlat-1)
  dlon = 360./nlon
  latmin = -90.
  latmax = 90.
  lonmin = 0.
  lonmax = 360.
  lon_grid = findgen(nlon)*dlon+lonmin
  lat_grid = findgen(nlat)*dlat+latmin
 end
'1.9x2.5': begin
  nlat = 96
  nlon = 144
  dlat = 180./(nlat-1)
  dlon = 360./nlon
  latmin = -90.
  latmax = 90.
  lonmin = 0.
  lonmax = 360.
  lon_grid = findgen(nlon)*dlon+lonmin
  lat_grid = findgen(nlat)*dlat+latmin
 end
endcase
print,'Lon: ',lon_grid[0],lon_grid[1],' - ',lon_grid[nlon-2],lon_grid[nlon-1]
print,'Lat: ',lat_grid[0],lat_grid[1],' - ',lat_grid[nlat-2],lat_grid[nlat-1]


;Read FINN2 emissions text file

 nfires = file_lines(txtfile)-1L
 
 ;FINN2 header: DAY,POLYID,FIREID,GENVEG,LATI,LONGI,AREA,BMASS,CO2,CO,...
 print,'reading: ',txtfile, nfires
 openr,ilun,txtfile,/get_lun
 sdum=' '
 readf,ilun,sdum
 vars = strsplit(sdum,',',/extract)
 nvars = n_elements(vars)
 ;for i=0,nvars-1 do print,i,': ',vars[i]
 isp1 = where(vars eq 'CO2')
 isp1 = isp1[0]
 print,'CO2: ', isp1, vars[isp1]
 isp2 = nvars-1
 nspec = isp2-isp1+1

 species = vars[isp1:isp2]
 print,'all species: ', species
 
 ;ivegvar = where(vars eq 'GENVEG') & ivegvar=ivegvar[0]
 ilatvar = where(vars eq 'LATI') & ilatvar=ilatvar[0]
 ilonvar = where(vars eq 'LONGI') & ilonvar=ilonvar[0]
 print,'day,lon,lat vars: ',vars[0],' ',vars[ilonvar],' ',vars[ilatvar]
 jday = fltarr(nfires)
 ;veg = intarr(nfires)
 lonin = fltarr(nfires)
 latin = fltarr(nfires)
 emis = fltarr(nspec,nfires)
 data1 = fltarr(nvars)
 for ifire=0L,nfires-1 do begin
    readf,ilun,data1
    jday[ifire] = data1[0]
    lonin[ifire] = data1[ilonvar]
    latin[ifire] = data1[ilatvar]
    ;veg[ifire] = data1[ivegvar]
    emis[*,ifire] = data1[isp1:isp2]
    if (data1[isp1] lt 0) then print,ifire,jday[ifire],lonin[ifire],latin[ifire],data1[isp1]
 endfor 
 free_lun,ilun

; grid emissions for only CO
 ispec = where(species eq 'CO')
 ispec = ispec[0]
 spec = species[ispec]
 print,ispec,' ',spec

 mw = 1. ;not needed for gases
 aerosol = 0
 iday = 0

  ;grid emissions
  emis_grid = fltarr(nlon,nlat,ndays)
  for ifire = 0L,nfires-1 do begin
    lon1 = lonin[ifire]
    lat1 = latin[ifire]
    if (lon1 lt 0.5*dlon) then lon1 = lon1+360.
    ilat = Round((lat1-(latmin+0.5*dlat))/dlat)
    ilon = Round((lon1-(lonmin+0.5*dlon))/dlon)
    if (ilon eq nlon) then ilon=0
    ;print,iday,lon1,lon_grid[ilon],lat1,lat_grid[ilat]
    emis_grid[ilon,ilat,iday] = emis_grid[ilon,ilat,iday] + emis[ispec,ifire]
   ;endif ;else print,'day: ',jday[ifire],' not included.'
  endfor

   ;convert gases from moles/day to molec/cm2/s
   ;skip poles
   for ilat=1,nlat-2 do begin
     gridarea = 4.e4*!pi*Rearth*Rearth*sin(0.5*dlat*rad_deg)/float(nlon) * cos(lat_grid[ilat]*rad_deg)
    sf = avog/gridarea/s_per_day
    emis_grid[*,ilat,*] = emis_grid[*,ilat,*] *sf
    if (sf lt 0) then print,'sf=',sf
   endfor

  ; write gridded emissions to netcdf file
  ncfile = path_new+newfilelab+'_'+spec+'_bb_surface_'+ymd_str+'_'+resol+'.nc'
  print,ncfile,min(emis_grid),max(emis_grid)

  ncid = ncdf_create(ncfile,/clobber)
  ; Define dimensions
  xid = ncdf_dimdef(ncid,'lon',nlon)
  yid = ncdf_dimdef(ncid,'lat',nlat)
  tid = ncdf_dimdef(ncid,'time',ndays)

 ; Define dimension variables with attributes
 xvarid = ncdf_vardef(ncid,'lon',[xid],/float)
 ncdf_attput, ncid, xvarid,/char, 'units', 'degrees_east'
 ncdf_attput, ncid, xvarid,/char, 'long_name', 'Longitude'
 yvarid = ncdf_vardef(ncid,'lat',[yid],/float)
 ncdf_attput, ncid, yvarid,/char, 'units', 'degrees_north'
 ncdf_attput, ncid, yvarid,/char, 'long_name', 'Latitude'
 tvarid = ncdf_vardef(ncid,'time',[tid],/float)
 ncdf_attput, ncid, tvarid,/char, 'long_name', 'Time'
 ncdf_attput, ncid, tvarid,/char, 'units', cal_units
 ncdf_attput, ncid, tvarid,/char, 'calendar', 'Gregorian'
 tvarid = ncdf_vardef(ncid,'date',[tid],/long)
 ncdf_attput, ncid, tvarid,/char, 'units', 'YYYYMMDD'
 ncdf_attput, ncid, tvarid,/char, 'long_name', 'Date'
 ;Define global attributes
 ncdf_attput,ncid,/GLOBAL,'title','FINNv2.5.1-MODIS+VIIRS NRT daily fire emissions'
 ncdf_attput,ncid,/GLOBAL,'authors','L. Emmons (NCAR)'
 ncdf_attput,ncid,/GLOBAL,'Grid',resol
 ncdf_attput,ncid,/GLOBAL,'History','Created '+todaystr+' from '+txtfile
 varid = ncdf_vardef(ncid, 'fire', [xid,yid,tid], /float)
 ncdf_attput, ncid, varid,/char, 'units', 'molecules/cm2/s'
 ncdf_attput, ncid, varid,/char, 'long_name', spec+' FINN2.5.1 NRT fire emissions'
 ncdf_control,ncid,/ENDEF
 ncdf_varput,ncid,'lon',lon_grid
 ncdf_varput,ncid,'lat',lat_grid
 ncdf_varput,ncid,'time',time
 ncdf_varput,ncid,'date',date
 ncdf_varput,ncid,'fire',emis_grid
 ncdf_close,ncid

end
