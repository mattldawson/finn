;-----------------------------------------------
; create images of FINN2-NRT emissions to use in Worldview
;-----------

pro map_finn2_worldview

  args = COMMAND_LINE_ARGS()

  if n_elements(args) ne 2 then begin
    print, 'Usage: idl -e map_finn2_worldview -args <date> <data_folder>'
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
  ymd_str = String(year,mm,dd,format='(i4,i2.2,i2.2)')

path_emis = data_path + '/emis_gridded/'
path_plot = data_path + '/finn_plots/'
pngfile = path_plot+'finn2.5.1nrt_coemis_worldview_'+datestr+'.png'

;FINN emissions file
file_emis = path_emis+'/emissions_finn251_modvrs_nrt_CO_bb_surface_'+ymd_str+'_0.5x0.5.nc'
if (file_test(file_emis) eq 0) then goto,skipplot

 ncid = ncdf_open(file_emis)
 ncdf_varget,ncid,'lon',lon_fire
 ncdf_varget,ncid,'lat',lat_fire
 ncdf_varget,ncid,'date',date_fire
 ncdf_varget,ncid,'fire',co_fire
 ncdf_close,ncid
 nlon = n_elements(lon_fire)
 nlat = n_elements(lat_fire)
 dlon = lon_fire[1]-lon_fire[0]
 dlat = lat_fire[1]-lat_fire[0]

indl = where(lon_fire ge 180.)
lon_fire[indl] = lon_fire[indl]-360.

;set_plot, 'x'
;loadct,13
set_plot, 'z'
loadct, 13, /silent, rgb_table=rgb
red=rgb(*,0)
green=rgb(*,1)
blue=rgb(*,2)
tvlct,red,green,blue

;image resolution
nx=2400
ny=1200
dpx = 360./float(nx)   ;0.15deg
lon_img=findgen(nx, increment=dpx, start=-180.+(dpx/2.))
lat_img=findgen(ny, increment=-dpx, start= 90.-(dpx/2.))
map_img = fltarr(nx,ny)
map_img[*,*]=!values.f_nan

sf = 255./(1.e12)   ;n_colors/max_value

map_set, /cylindrical, /noborder, /clip, /isotropic, xmargin=[0,0], ymargin=[0,0], limit=[-180.,-90.,180.,90.]

for ilon=0,nlon-1 do begin
 for ilat=0,nlat-1 do begin
   dat1 = (co_fire[ilon,ilat])
   if (dat1 gt 0.) then begin
     lon1 = lon_fire[ilon]-0.5*dlon
     lat1 = lat_fire[ilat]-0.5*dlat
     lon2 = lon1 + dlon
     lat2 = lat1 + dlat
     indlon = where(lon_img ge lon1 and lon_img lt lon2, nln)
     indlat = where(lat_img ge lat1 and lat_img lt lat2, nlt)
     icol = dat1*sf < 255.
     for jlon = 0,nln-1 do begin
       for jlat = 0,nlt-1 do begin
         map_img[indlon[jlon],indlat[jlat]] = icol
       endfor
     endfor
   endif
 endfor
endfor

write_png, pngfile, map_img, /order, transparent=[0], red, green, blue

print,'wrote: ',pngfile
skipplot:

end

