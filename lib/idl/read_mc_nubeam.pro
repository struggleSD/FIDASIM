FUNCTION read_mc_nubeam,infile,ntotal=ntotal,e_range=e_range,p_range=p_range,particle_weight = particle_weight,btipsign=btipsign
    ;+#read_mc_nubeam
    ;+Reads guiding center Monte Carlo NUBEAM fast-ion distribution file
    ;+***
    ;+##Arguments
    ;+    **infile**: NUBEAM Monte Carlo distribution file
    ;+
    ;+##Keyword Arguments
    ;+    **ntotal**: Total number of fast-ions
    ;+
    ;+    **e_range**: Energy range of particles to consider
    ;+
    ;+    **p_range**: Pitch range of particles to consider
    ;+
    ;+    **particle_weight**: Set particle/marker weight such that sum(particle_weights) = ntotal: Defaults to `ntotal`/nparticles
    ;+
    ;+    **btipsign**: Sign of the dot product between the current and magnetic field (Required)
    ;+
    ;+##Return Value
    ;+Distribution structure
    ;+
    ;+##Example Usage
    ;+```idl
    ;+IDL> dist = read_spiral("./spiral_file.TXT",time=1.0, ntotal=1e19)
    ;+```
    if not keyword_set(btipsign) then begin
        error,'btipsign is not set.',/halt
    endif

    if not keyword_set(ntotal) and not keyword_set(particle_weight) then begin
        warn,'Ntotal not set. Setting arbitrarily to 1e19'
        ntotal = 1.d19
    endif

    zzz=FINDFILE(infile)
    if zzz eq '' then begin
        error, 'Nonexistent file: '+infile,/halt
    endif
    
    openr,unit,infile, /get_lun
    line=' '
    readf,unit,line           ; read string
    readf,unit,line
    pos=strpos(line,'N=')
    if pos eq -1 then begin
        error,'Second line is missing the number of points',/halt
    endif

    w = stregex(line,'N *= *([0-9]*)',/sub,/extract)
    npts = long(w[1])
    if npts lt 5 then begin
        error,'Too few points '+strtrim(npts,2),/halt
    endif
    
    ; Get time
    readf,unit,line
    parts=str_sep(line, ' ')
    w=where(parts eq 'TIME',nw)
    if nw eq 0 then begin
        error,'Time not found on 3rd line',/halt
    endif
    i=1
    while 1 do begin
        s = parts[w[0]+i]
        if s ne '' and s ne '=' then begin
            time = float(s)
            break
        endif
        i = i+1
    endwhile
    data=fltarr(4,npts)
    
    ready=0
    while not ready do begin
        readf,unit,line  ; Description line
        pos=strpos(line,'R(cm)')
        if pos gt -1 then ready=1
    endwhile
 
    for i=0L,npts-1 do begin
        readf,unit,line           ; read string
        line=strcompress(line)
        parts = str_sep(line, ' ') & np=n_elements(parts)
        if parts(0) eq '' then parts=shift(parts,-1) ; accommodate blank before 1st

        while parts(np-1) eq '' do np=np-1

        if np ne 4 then begin
            error,'Wrong number of entries on line: '+line
        endif else begin
            data[*,i]=parts[0:np-1]
        endelse
        print,format='(f7.2,"%",A,$)',100.0*(i+1)/float(npts),string(13b)
    endfor   
    free_lun, unit

    r=double(reform(data[0,0:npts-1]))
    w=double(reform(data[1,0:npts-1]))
    pitch=double(reform(data[2,0:npts-1]))*btipsign
    energy=reform(data[3,0:npts-1])*1.d-3 ;keV
    orbit_class = replicate(1,npts)
    if not keyword_set(particle_weight) then begin
        particle_weight = ntotal/float(npts)
    endif
    weight = replicate(particle_weight,npts)

    if not keyword_set(e_range) then begin
        e_range = [min(energy),max(energy)]
    endif
    if not keyword_set(p_range) then begin
        p_range = [min(pitch),max(pitch)]
    endif

    ww = where(energy ge e_range[0] and energy le e_range[1],nw)
    if nw eq 0 then begin
        error,'No particles fall in requested energy range',/halt
    endif
    wwp = where(pitch[ww] ge p_range[0] and pitch[ww] le p_range[1],nwp)
    if nwp eq 0 then begin
        error,'No particles fall in the requested pitch range',/halt
    endif
    ww = ww[wwp]
    nw = n_elements(ww)

    print, 'Time: ',time  
    print,'Number of markers: ',npts
    print,'Number of markers in phase space: ',nw
    print, 'Total Number of Fast-ions in phase space: ',particle_weight*nw

    fbm_struct = {type:2,time:double(time),data_source:file_expand_path(infile), $
                  nparticle:long(nw),nclass:1,r:r[ww],z:w[ww],$
                  energy:energy[ww],pitch:pitch[ww],class:orbit_class[ww],$
                  weight:weight[ww]}

    return, fbm_struct
END

