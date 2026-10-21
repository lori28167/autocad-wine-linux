# AutoCAD 2026 su Linux con Wine

Istruzioni e script per far girare **AutoCAD 2026** su Linux con **Wine**, senza macchine virtuali.

Testato su Arch Linux (Omarchy, Hyprland) con GPU AMD Radeon 840M (driver RADV) e Wine 11.17.

> **Serve una licenza AutoCAD valida.** Questo repo non contiene file di Autodesk e non aggira nessun controllo di licenza. Contiene solo:
> - una patch per Wine (software open source);
> - script per configurare il prefisso;
> - un font sostitutivo generato da Liberation Sans.

## Cosa funziona

- Installazione con l'installer ufficiale (web installer).
- Login con l'account Autodesk tramite il browser di Linux.
- Disegno, salvataggio, ribbon, palette e pagina iniziale.
- Il primo avvio è lento perché .NET compila le sue librerie; poi AutoCAD gira fluido.

## Problemi noti

- **Dialogo "Desktop Licensing Service - Connection Lost"**: compare in ogni sessione circa 2 minuti dopo l'avvio, anche se il servizio licenze funziona. La causa non è stata trovata.
  - **Prima che compaia, salva il disegno.** Poi chiudi e riavvia AutoCAD.
  - Abbassa l'intervallo del salvataggio automatico con `SAVETIME` → `5`.
- **Il file del profilo (`Profile.aws`) si gonfia durante la sessione**: si riempie di blocchi `<AcApData>` duplicati e può arrivare a decine o centinaia di MB in pochi minuti.
  - Conseguenze: chiusura lentissima, avvio di minuti e a volte l'errore "unable to load profile file".
  - Il launcher `autocad` rimette una copia pulita del profilo a ogni avvio. Il prezzo è che le modifiche al layout dell'interfaccia non restano tra una sessione e l'altra; le variabili di sistema restano.
- **Chiusura**: invece di aspettare, usa **"Chiudi AutoCAD"** dal menu delle app, cioè lo script `chiudi-autocad`. Il disegno non salvato va perso.
- **Non usare DXVK**: rompe la vista di disegno.
- **Non installare `msxml3` o `msxml6` con winetricks**: viene installata solo la versione a 32 bit e `acad.exe`, che è a 64 bit, non parte più.

## Cosa cambia la patch di Wine

`wine-autocad.patch` modifica quattro parti di Wine:

| File | Modifica | Perché |
|---|---|---|
| `dlls/kernelbase/registry.c` | `RegLoadAppKeyW` implementata davvero: legge gli hive binari `regf` | Senza, i componenti Autodesk non leggono i loro file di registro privati |
| `server/process.c` | `services.exe` e i servizi risultano in sessione 0 | I runtime Go e .NET dei servizi Autodesk lo usano per capire se girano come servizio |
| `dlls/ole32/ole2.c` | `RevokeDragDrop` non va in crash se il drop target è già stato distrutto | AutoCAD distrugge il drop target prima di revocarlo |
| `dlls/urlmon/sec_mgr.c` | Gli URL `res:///` senza host ricevono una zona di sicurezza valida | Le pagine interne di AutoCAD usano `res:///` |

Vengono ricompilati solo questi quattro moduli. Lo script costruisce un Wine privato in `~/.cache/wine-autocad-build/wine-custom` che usa tutto il resto dal Wine di sistema. **Il Wine di sistema non viene toccato.**

## Requisiti

Su Arch:

```sh
sudo pacman -S wine winetricks mingw-w64-gcc libarchive libfaketime python-fonttools ttf-liberation
```

Su altre distro i nomi dei pacchetti cambiano.

> **Le versioni devono coincidere.** `build-wine.sh` scarica i sorgenti della stessa versione del Wine di sistema (`wine --version`), perché i moduli non modificati vengono presi da `/usr/lib/wine`. **Dopo ogni aggiornamento di Wine bisogna rilanciare `build-wine.sh`**, altrimenti i moduli non combaciano e AutoCAD può non partire. La patch si applica sia a 11.17 sia a 11.20.

## Installazione

Tutti i comandi vanno lanciati dalla cartella del repo.

### 1. Compila il Wine con la patch

```sh
./scripts/build-wine.sh          # usa la versione del Wine di sistema
# oppure, per una versione precisa:
./scripts/build-wine.sh 11.17
```

### 2. Installa gli script e i collegamenti nel menu

```sh
./scripts/install-scripts.sh
```

Copia `wine-autocad`, `autocad`, `chiudi-autocad` e `adsk-url-handler` in `~/.cache/wine-autocad-build/`. Aggiunge al menu le voci **AutoCAD 2026** e **Chiudi AutoCAD**. Registra anche il gestore dei link `adskidmgr://`, che serve al login.

### 3. Prepara il prefisso Wine

```sh
./scripts/setup-prefix.sh
```

Il prefisso è `~/.wine-autocad`. Lo script:
- installa `corefonts`, `vcrun2022` e `dotnet48`;
- imposta Windows 11 (build 22631);
- installa il runtime **WebView2 109**: le versioni più recenti richiedono DirectComposition, che Wine non ha;
- attiva il rendering software per WPF;
- genera "Microsoft Sans Serif" da Liberation Sans.

`dotnet48` ci mette parecchio.

### 4. Installa AutoCAD

Scarica il web installer dal tuo account Autodesk, per esempio `AutoCAD_2026_..._setup_webinstall.exe`. Poi:

```sh
B=~/.cache/wine-autocad-build
mkdir -p ~/.wine-autocad/drive_c/autocad-setup
bsdtar -xf ~/Downloads/AutoCAD_2026_*_setup_webinstall.exe -C ~/.wine-autocad/drive_c/autocad-setup
cd ~/.wine-autocad/drive_c/autocad-setup
AUTOCAD_FAKETIME=1 $B/wine-autocad Setup.exe
```

`AUTOCAD_FAKETIME=1` avvia l'installer con la data impostata a settembre 2024. I pacchetti sono firmati da Autodesk con un certificato oggi scaduto. Su Windows la firma resta valida grazie al timestamp, ma Wine non lo considera e rifiuterebbe i pacchetti. Serve **solo** per l'installazione, non per usare AutoCAD.

**Se il servizio CER (Customer Error Reporting) non si installa**, installalo a mano dall'MSI che l'installer ha estratto in `Temp`:

```sh
$B/wine-autocad msiexec /i 'C:\users\<utente>\AppData\Local\Temp\{...}\x64\CER\cer.msi' /qn 'INSTALLDIR=C:\PROGRA~1\Autodesk' ADSK_ODIS_SETUP=1 REBOOT=ReallySuppress
```

### 5. Primo avvio e login

Avvia **AutoCAD 2026** dal menu delle app. Al login si apre il browser di Linux; al termine il link `adskidmgr://` ritorna ad AutoCAD da solo.

### 6. Salva il profilo pulito

Dopo il primo avvio riuscito:
1. sistema l'interfaccia come preferisci;
2. chiudi AutoCAD normalmente;
3. salva il profilo come copia di riferimento:

```sh
cp ~/.wine-autocad/drive_c/users/$USER/AppData/Roaming/Autodesk/"AutoCAD 2026"/R25.1/enu/Support/Profiles/"Unnamed Profile"/Profile.aws \
   ~/.cache/wine-autocad-build/Profile.aws.good
```

Controlla che il file sia piccolo, qualche decina di KB. Se è già gonfio, tieni solo il primo blocco `<AcApData>` e chiudi il file con:

```
	</StorageRoot>
</Profile>
```

Dal prossimo avvio il launcher ripristina questa copia ogni volta.

## Diagnostica

- Log dell'ultimo avvio: `~/.cache/wine-autocad-build/logs/autocad-last.log`
- Log del servizio licenze: `~/.wine-autocad/drive_c/ProgramData/Autodesk/AdskLicensingService/Log/`
- Log di login: `~/.wine-autocad/drive_c/users/$USER/AppData/Local/Autodesk/Identity Services/Log/`
- Per tracciare: `WINEDEBUG=+canale ~/.cache/wine-autocad-build/wine-autocad acad.exe`, lanciato dalla cartella di AutoCAD

## Struttura

```
wine-autocad.patch        patch per Wine
scripts/build-wine.sh     compila i moduli e crea il Wine privato
scripts/install-scripts.sh  installa launcher e voci di menu
scripts/setup-prefix.sh   prepara il prefisso
scripts/wine-autocad      wrapper: Wine con la patch + prefisso + WebView2
scripts/autocad           launcher (ripristina il profilo e avvia acad.exe)
scripts/chiudi-autocad    chiusura forzata
scripts/adsk-url-handler  passa i link di login ad AutoCAD
tools/make_micross.py     genera "Microsoft Sans Serif" da Liberation Sans
desktop/                  voci del menu delle app
```

## Avvertenze

- La configurazione funziona su una macchina. Gli script sono stati ricostruiti dai passaggi fatti a mano e non sono stati eseguiti tutti insieme da zero. Se qualcosa non va, apri una issue.
- AutoCAD e Autodesk sono marchi di Autodesk, Inc. Questo progetto non è affiliato ad Autodesk.
- La patch di Wine è rilasciata sotto LGPL 2.1 o successiva, come Wine. Gli script sono sotto licenza MIT.
