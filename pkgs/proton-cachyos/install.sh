runHook preInstall

echo "@pname@ should not be installed into environments. Please use programs.steam.extraCompatPackages instead." > $out

mkdir $steamcompattool
ln -s $src/* $steamcompattool
rm $steamcompattool/compatibilitytool.vdf
cp $src/compatibilitytool.vdf $steamcompattool

runHook postInstall
