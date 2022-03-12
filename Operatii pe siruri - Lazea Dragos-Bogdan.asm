.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern exit: proc
extern fopen: proc
extern fclose: proc
extern fscanf: proc
extern fprintf: proc
extern printf: proc
extern scanf: proc
extern gets: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date

; mesaje de afisare:
mesaj_fisier db "Incarcare fisier:",13,10,0
mesaj_choose db "Selecteaza operatie:",13,10,"1. Histograma",13,10,"2. Calculul mediei bazat pe histograma", 13, 10,"3. Calculul deviatiei standard", 13, 10, "4. Eliminare valori",13,10,0
mesaj_salvare db "Salvat in %s",13,10,0
mesaj_err_file db "Eroare la deschiderea fisierului, incarcati un nou fisier.", 13, 10, 0
mesaj_afisare_sir db "Numerele din fisier: ",0
mesaj_op_invalida db "Operatie invalida! Alegeti una dintre optiunile 1, 2, 3 sau 4.", 13, 10, 0
mesaj_histograma db "Histograma valorilor: ", 0
mesaj_eliminare db "Sirul dupa eliminarea valorilor: ", 0
msg_err db "Eroare la deschiderea fisierului", 13, 10, 0

; nume_fisiere:
file_name db 2000 dup(0)
minmax_file db "minmax.txt", 0
histograma_file db "histograma.txt", 0
sigma_file db "deviatia_standard.txt", 0
media_file db "media.txt", 0

; moduri de deschidere a fisierelor:
mode_read db "r", 0
mode_write db "w", 0

; formate de scriere/afisare
format db "%d",0
format_minim db "min = %d", 13, 10, 0
format_maxim db "max = %d", 13, 10, 0
format_d db "%d ",0
format_media_f db "media = %lf", 13, 10, 0
format_sigma db "sigma = %lf", 13, 10, 0
format_string db "%s",0
format_lf db "%lf", 0

; date si variabile auxiliare
sir dd 2000 dup(0) ; sirul de numere citit din fisier
lungime dd 0 ; lungimea sirului
file_pointer dd 0 ; pointer spre un fisier deschis in mod r/w
nb dd 0
ii dd 0
minim dd 0
maxim dd 0
hist dd 2000 dup(0)
lung_hist dd 0
aux1 dd 0
aux2 dd 0
newline db 13, 10, 0
media_int dd 0
media_float dq 0.00
nr dd 0
m32int dd 0
i dd 0
var32 dd 0
sigma dq 0.0 ; deviatia standard
sum dq 0.0 ; suma folosita pentru calculul deviatiei standard
m64fp dq 0.0
h dd 0
doi dd 2
zero dd 0.0
m16int dw 0
double_sigma dq 0.0 ; 2*sgima
op dd 0 ;operatia introdusa
calculat dd 0 ; variabila care are valoarea 0 daca histograma nu a fost inca determinata si 1 daca aceasta a fost determinata si salvata in memorie
calculat_med dd 0 ; 0 daca media nu a fost determinata, sau 1 daca aceasta a fost determinata
calculat_sig dd 0 ; 0 daca deviatia standard nu a fost inca determinata si 1 in caz contrar
sigma_floor dd 0 ; partea intreaga a valorii absolute a numarului 2*sigma
sigma_floor_negative dd 0 ; opusul partii intregi a valorii absolute a numarului 2*sigma

.code

sir_min proc		;functie in conventia stdcall
	push ebp
	mov ebp, esp
	mov edx, [ebp+8] ;dimensiunea sirului
	mov ebx, [ebp+12] ;adresa de inceput a sirului
	mov ecx, 0	;folosit pentru parcurgerea sirului
	mov esi, 0
	mov eax, [ebx+ecx] ; initializez minimul cu prima valoare din sirul primit ca parametru
	inc esi		;indicele elementului curent
	add ecx, 4
	et_minim:
		cmp esi, edx
		je et_end_minim
		cmp [ebx+ecx], eax ; compar elementul de pe pozitia curenta cu minimul determinat pana acum
		jge et_continue
		mov eax, [ebx+ecx]
		et_continue:
		inc esi
		add ecx, 4
	jmp et_minim
	et_end_minim:
	mov esp, ebp
	pop ebp
	ret 8
sir_min endp
		
sir_max proc		;conventia stdcall
	push ebp
	mov ebp, esp
	mov edx, [ebp+8] ;dimensiunea sirului (primul parametru)
	mov ebx, [ebp+12] ;adresa de la care incepe sirul (al doilea parametru)
	mov ecx, 0
	mov esi, 0
	mov eax, [ebx+ecx]
	inc esi
	add ecx, 4
	et_maxim:
		cmp esi, edx
		je et_end_maxim
		cmp [ebx+ecx], eax
		jle et_salt
		mov eax, [ebx+ecx]
		et_salt:
		inc esi
		add ecx, 4
	jmp et_maxim
	et_end_maxim:
	mov esp, ebp
	pop ebp
	ret 8
sir_max endp

; 1. Functie pentru histograma valorilor din sirul citit

histograma_valorilor proc	; conventia stdcall
	push ebp
	mov ebp, esp
	mov ecx, [ebp+8] 		; primul parametru, lungimea sirului de numere intregi
	mov edx, [ebp+12] 		; al doilea parametru, adresa de inceput a sirului
	mov ebx, [ebp+16] 		; al treilea parametru, adresa de inceput a histogramei
		
	mov esi, 0
	et_sir:					; parcurg sirul de la primul pana la ultimul element
		cmp esi, ecx
		je et_end_sir
		mov eax, [edx+4*esi]; elementul curent din sir
		
		mov edi, minim		; parcurg histograma incepand cu elementul minim, in paralel cu sirul (pentru fiecare element din sir)
		mov i, edi 			; elementul curent din histograma
		mov edi, 0			; pozitia in histograma
		et_hist:
			cmp eax, i		; verific daca am ajuns cu parcurgerea la pozitia din histograma corespunzatoare elementului curent din sir
			je et_end_hist
			inc edi			; trec mai departe in histograma
			inc i			; incrementez contorul ce parcurge numerele incepand cu minimul din sir, pentru ca inca nu am ajuns pe pozitia corespunzatoare numarului curent din sir
		jmp et_hist
		et_end_hist:		; daca am ajuns in histograma pe pozitia corespunzatoare elementului curent din sir
		mov eax, [ebx+4*edi]; incrementez valoarea de pe pozitia din histograma corespunzatoare numarului curent din sir 
		inc eax
		mov [ebx+4*edi], eax
		inc esi				; trec la elementul urmator din sir
	jmp et_sir
	et_end_sir:
	mov eax, [ebp+16] ; returnez in eax adresa de inceput a histogramei valorilor
	mov esp, ebp
	pop ebp
	ret 12
histograma_valorilor endp

; 2. Media valorilor din sir pe baza histogramei

media_valorilor proc 	; conventia stdcall
	push ebp
	mov ebp, esp
	mov ecx, [ebp+8] ;primul parametru, lungimea histogramei
	mov ebx, [ebp+12] ;al doilea parametru, adresa de la care incepe histograma in memorie
	finit			; initialize coprocesorul matematic
	fldz
	mov esi, 0 ; indicele de parcurgere al histogramei
	mov edi, minim
	mov i, edi ; parcurg toate numerele de la minim pana la maxim, verificand de cate ori apare fiecare in sir
	mov nr, 0 ; numarul total de numere din sir
	et_media:
		cmp esi, ecx
		je et_end_media
		mov edi, [ebx+esi*4] ; numarul de aparitii al unui element in sir (salvat in histograma)
		add nr, edi
		mov eax, i
		mul edi
		mov var32, eax
		fiadd var32 ; in varful stivei se va afla la finalul parcurgerii suma tuturor elementelor din sir
		inc esi
		inc i      ; trec la elementul urmator in histograma
	jmp et_media
	
	et_end_media:
	fidiv nr		; impart suma tuturor numerelor la numarul total de numere din sir pentru a obtine in ST(0) media numerelor din sir
	mov esp, ebp
	pop ebp
	ret 8;
media_valorilor endp

; 3. Deviatia standard

deviatia_standard proc	; conventia stdcall
	push ebp
	mov ebp, esp
	mov ecx, [ebp+8] ;primul parametru, lungimea histogramei
	mov ebx, [ebp+12] ;al doilea parametru, adresa de inceput a histogramei
	mov edi, minim
	mov i, edi ; parcurg histograma
	mov esi, 0 ; indicele in histograma
	mov nr, 0
	finit
	fldz
	fstp sum	; initializez suma de sub radical cu 0
	et_dev:
		cmp esi, ecx
		je et_end_dev
		fild i	
		fsub media_float
		fabs
		fst m64fp
		fmul m64fp ; ridic la patrat modulul diferentei
		mov edi, [ebx+4*esi]
		mov h, edi ; elementul de la pozitia esi din histograma
		fimul h ; inmultesc patratu diferentei cu numarul de aparitii al numarului in sir (salvat in histograma)
		fadd sum ; adun la vechea valoare a sumei
		fstp sum ; salvez noua valoare a sumei in variabila sum
		mov edx, h
		add nr, edi ; adun numarul de aparitii al elementului curent la numarul de numere din sir
		inc esi ; trec la urmatorul element in histograma
		inc i
	jmp et_dev
	et_end_dev:
	dec nr
	fld sum 
	fidiv nr ; impart suma la numarul de numere minus 1
	fsqrt ; extrag radical, iar rezultatul, reprezentand deviatia standard se va afla in ST(0)
	mov esp, ebp
	pop ebp
	ret 8
deviatia_standard endp

; 4. Eliminarea valorilor ce se afla in exteriorul intervalului [-2*sigma, 2*sigma]

eliminare_valori proc ; conventia stdcall
	push ebp
	mov ebp, esp
	mov ecx, [ebp+8] ; primul parametru, lungimea sirului de numere
	mov ebx, [ebp+12] ; al treilea parametru, adresa de inceput a sirului
	mov eax, [ebp+16] ; al treilea parametru, partea intreaga a modulului numarului 2*sigma (sigma este deviatia standard)
	mov edx, 0
	sub edx, eax ; opusul partii intregi a modulului numarului 2*sigma
	mov esi, 0	; parcurg sirul
	et_elim:
		cmp esi, ecx	
		je et_end_elim
		mov edi, [ebx+4*esi] ; elementul curent din sir
		cmp edi, eax	; daca elementul curent din sir este mai mare strict decat 2*sigma in locul lui se va pune in sir valoarea 0
		jle et_cont1
		mov edi, 0
		mov [ebx+4*esi], edi 
		et_cont1:      ; ; daca elementul curent din sir este mai mic strict decat -2*sigma in locul lui se va pune in sir valoarea 0
		cmp edi, edx
		jge et_cont2
		mov edi, 0
		mov [ebx+4*esi], edi
		et_cont2:
		inc esi		; trec la urmatorul element in sir
	jmp et_elim
	et_end_elim:
	mov eax, ebx ; returnez in eax adresa de inceput a sirului, dupa eliminarea valorilor
	mov esp, ebp
	pop ebp
	ret 12
eliminare_valori endp

; macro pentru afisarea unui rand nou
print_newline macro
	push offset newline
	call printf
	add esp, 4
endm

; macro pentru afisarea unui sir pe ecran
print_array macro n,v
	local bucla, final
	mov esi, 0 ; de la 0	
	mov ebx, 0
	mov ebx, n 
	dec ebx ; la n-1

	bucla:
		cmp esi,ebx
		ja final
	
		mov eax,v[4*esi]

		push eax	
		push offset format_d
		call printf
		add esp, 8

		inc esi
	jmp bucla

	final:
	print_newline
endm

; macro pentru citirea unui sir dintr-un fisier deschis in modul r 
fscanf_array macro vect, file, len
	local et_cit, et_end_cit
	mov esi, 0
	et_cit:
		lea edx, vect[esi*4]
		push edx
		push offset format
		push file
		call fscanf
		add esp, 12
		cmp eax, 1 ; daca fscanf a returnat o valoare diferita de 1, inseamna ca s-a ajuns la finalul sirului de numere din fisier, altfel se trece la citirea urmatorului element
		jne et_end_cit
		inc esi
	jmp et_cit
	et_end_cit:
	mov len, esi
endm

; macro pentru deschiderea unui fisier in modul specificat de parametrul mode
file_open macro name_of_file, mode
	push offset mode
	push offset name_of_file
	call fopen
	add esp, 8
endm

; macro pentru inchiderea unui fisier deja deschis
file_close macro pointer_to_file
	push pointer_to_file
	call fclose
	add esp, 4
endm

; macro pentru initializarea unui sir cu valori de 0 pe toate pozitiile
init_array macro vect, len
	local et_init, et_end_init
	mov esi, 0
	et_init:
		cmp esi, len
		je et_end_init
		mov vect[esi*4], 0
		inc esi
	jmp et_init
	et_end_init:
endm

; macro pentru scrierea unui sir intr-un fisier deschis in modul w
fprintf_array macro vect, len, p_file
	local et_scr, et_end_scr
	mov esi, 0
	et_scr:
		cmp esi, len
		je et_end_scr
		push vect[esi*4]
		push offset format_d
		push p_file
		call fprintf
		add esp, 12
		inc esi
	jmp et_scr
	et_end_scr:
endm

start:
	;aici se scrie codul
	
	;cer utilizatorului sa introduca fisierul ce contine sirul de numere
	
	et_file_load:
	
	push offset mesaj_fisier
	call printf
	add esp, 4
	
	push offset file_name
	push offset format_string
	call scanf
	add esp, 8
	
	et_cit:
	;deschid fisierul in mod de citire
	
	file_open file_name, mode_read
	mov file_pointer, eax
	
	cmp eax, 0
	jne et_ok
	push offset mesaj_err_file	; daca a aparut o eroare la deschiderea fisierului, afisez un mesaj de eroare pe ecran
	call printf
	add esp, 4
	jmp et_file_load
	
	et_ok:
	
	;citesc numerele din fisier si le retin in variabila sir
	
	fscanf_array sir, file_pointer, lungime
	file_close file_pointer
	
	;afisez numerele din sir pe ecran
	push offset mesaj_afisare_sir
	call printf
	add esp, 4
	print_array lungime, sir
	
	;determin minimul si maximul din fisier si le scriu pe ecran si in fisier
	
	push offset sir
	push lungime
	call sir_min
	mov minim, eax
	
	push offset sir
	push lungime
	call sir_max
	mov maxim, eax
	
	file_open minmax_file, mode_write
	mov file_pointer, eax
	
	push minim
	push offset format_minim
	push file_pointer
	call fprintf
	add esp, 12
	
	push maxim
	push offset format_maxim
	push file_pointer
	call fprintf
	add esp, 12
	
	file_close file_pointer
	
	push minim
	push offset format_minim
	call printf
	add esp, 8
	
	push maxim 
	push offset format_maxim
	call printf
	add esp, 8

	push offset minmax_file
	push offset mesaj_salvare
	call printf
	add esp, 8
	
	; afisez un mesaj prin care cer utilizatorului sa introduca o operatie dintre cele permise (1/2/3/4)
	et_select_op:
	
	push offset mesaj_choose
	call printf
	add esp, 4
	
	push offset op
	push offset format
	call scanf
	add esp, 8
	
	mov ebx, op
	cmp op, 1
	je et_op1
	cmp ebx, 2
	je et_op2
	cmp op, 3
	je et_op3
	cmp op, 4
	je et_op4
	
	push offset mesaj_op_invalida
	call printf
	add esp, 4
	jmp et_select_op
	
	; 1. Histograma valorilor 
	
	et_op1:
	
	mov ebx, maxim
	sub ebx, minim
	inc ebx
	mov lung_hist, ebx   ; lungimea histogramei este maxim-minim+1
	
	init_array hist, lung_hist ; initializez histograma cu valori de 0
	
	push offset hist
	push offset sir
	push lungime
	call histograma_valorilor
	
	file_open histograma_file, mode_write
	mov file_pointer, eax
	
	fprintf_array hist, lung_hist, file_pointer
	file_close file_pointer
	mov calculat, 1		; indic faptul ca histograma a fost cdeterminata
	
	cmp op, 2			; daca operatia nu este cea de determinare a histogramei, dar ea a fost necesara pentru una din celelalte operatii, sar la portiunea de cod corespunzatoare operatiei respective
	je et_h_from_f
	cmp op, 3
	je et_h_from_f
	cmp op, 4
	je et_h_from_f
	
	push offset mesaj_histograma
	call printf
	add esp, 4
	print_array lung_hist, hist
	
	push offset histograma_file
	push offset mesaj_salvare
	call printf
	add esp, 8
	
	jmp et_select_op
	
	; 2. Media valorilor din sir
	
	et_op2:
	
	cmp calculat, 0 	; daca histograma nu a fost inca determinata, dar ea este necesara pentru calculul medie, sar la portiunea de cod care determina histograma
	je et_op1
	
	et_h_from_f:
	file_open histograma_file, mode_read
	mov file_pointer, eax
	fscanf_array hist, file_pointer, lung_hist
	
	push offset hist
	push lung_hist
	call media_valorilor
	fst media_float
	mov calculat_med, 1  ; indic faptul ca histograma a fost calculata
	
	file_open media_file, mode_write
	mov file_pointer, eax
	
	push dword ptr[media_float+4]
	push dword ptr[media_float]
	push offset format_lf
	push file_pointer
	call fprintf
	add esp, 16
	
	file_close file_pointer
	
	cmp op, 3  ; daca operatia introdusa nu este cea de determinare a mediei, dar ea este necesara pentru operatia introdusa, revin la bucata de cod corespunzatoare operatiei introduse
	je et_dev
	cmp op, 4
	je et_dev
	
	push dword ptr[media_float+4]
	push dword ptr[media_float]
	push offset format_media_f
	call printf
	add esp, 12
	
	push offset media_file
	push offset mesaj_salvare
	call printf
	add esp, 8
	
	jmp et_select_op
	
	; 3. Deviatia standard pe baza histogramei
	
	et_op3:
	
	cmp calculat_med, 0			; daca media nu a fost inca determinata (ea fiind necesara calculului deviatiei standard), se calculeaza intai media
	je et_op2
	
	et_dev:
	push  offset hist
	push lung_hist
	call deviatia_standard
	fst sigma
	mov calculat_sig, 0
	
	file_open sigma_file, mode_write
	mov file_pointer, eax
	
	push dword ptr[sigma+4]
	push dword ptr[sigma]
	push offset format_lf
	push file_pointer
	call fprintf
	add esp, 16
	
	file_close file_pointer
	
	cmp op, 4		; daca operatia introdusa este cea de eliminare, deviatia standard fiind necesara eliminarii valorilor, se revine la operatia de eliminare dupa calculul deviatiei
	je et_del
	
	push dword ptr[sigma+4]
	push dword ptr[sigma]
	push offset format_sigma
	call printf
	add esp, 12
	
	push offset sigma_file
	push offset mesaj_salvare
	call printf
	add esp, 8
	
	jmp et_select_op
	
	; 4. Eliminarea valorilor ce se afla in exteriorul intervalului [-2*sigma, 2*sigma] (acestea vor fi inlocuite cu 0)
	
	et_op4:
	
	cmp calculat_sig, 0
	je et_op3
	
	et_del:
	
	file_open sigma_file, mode_read
	mov file_pointer, eax
	
	push offset dword ptr[sigma+4]
	push offset dword ptr[sigma]
	push offset format_lf
	push file_pointer
	call fscanf
	add esp, 16
	
	file_close file_pointer
	
	finit			; initializez coprocesorul matematic 
	fld sigma		; incarc valoarea deviatiei standard pe stiva coprocesorului
	fimul doi		; inmultesc cu 2 pentru a obtine valoarea lui 2*sigma
	fst double_sigma	; salvez valoarea 2*sigma intr-o variabila
	fabs			; determin valoarea absoluta a numarului 2*sigma
	frndint			; rotunjesc valoarea absoluta a numarului 2*sigma
	fist sigma_floor ; salvez in variabila sigma_floor
	fld double_sigma ; incarc din nou pe stiva valoarea 2*sigma
	fabs			; valoare absoluta
	ficom sigma_floor	; compar valoarea rotunjita cu valoarea nerotunjita a lui 2*sigma
	fstsw ax		; salvez registrul de stare al coprocesorului in registrul ax
	fwait			; astept sa se termine operatia de incarcare a registrului de stare al coprocesorului in registrul ax
	sahf			; incarc continutul din ah (care contine flag-urile coprocesorului in urma incarcarii lor in ax) in registrul de stare al procesorului
	ja et_next		; pot folosi instructiunile de salt pentr intregi fara semn deoarece flag-urile coprocesorului coincid acum cu cele ale procesorului
	sub sigma_floor, 1 	; daca valoarea rotunjita este mai mare decat valoarea reala, scad 1 din valoarea rotunjita pentru a obitine partea intreaga a valorii absolute a numarului 2*sigma
	et_next:
	
	file_open file_name, mode_read
	mov file_pointer, eax
	
	fscanf_array sir, file_pointer, lungime
	
	file_close file_pointer
	
	push sigma_floor 		; in locul valorilor care sunt in exteriorul intervalului [-2*sigma, 2*sigma] pun 0 in sir
	push offset sir
	push lungime
	call eliminare_valori
	
	file_open file_name, mode_write
	mov file_pointer, eax
	
	fprintf_array sir, lungime, file_pointer
	
	file_close file_pointer
	
	push offset mesaj_eliminare
	call printf
	add esp, 4
	print_array lungime, sir
	
	push offset file_name
	push offset mesaj_salvare
	call printf
	add esp, 8
	
	mov calculat, 0				; semnalizez ca histograma, media si deviatia standard nu au fost inca determinate pentru sirul obtinut in urma stergerii anterioare, pentru a obtine rezultate corecte la fiecare pas
	mov calculat_med, 0
	mov calculat_sig, 0
	
	et_alegere:
	jmp et_cit
	
	;terminarea programului
	push 0
	call exit
end start
