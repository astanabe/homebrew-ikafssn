class Ikafssn < Formula
  desc "K-mer-based alignment-free similarity search for nucleotide sequences"
  homepage "https://github.com/astanabe/ikafssn"
  url "https://github.com/astanabe/ikafssn/archive/refs/tags/v0.1.2026.10.27.tar.gz"
  sha256 "44c97fb2af42bb677fa2cde8d30795f11bf66452bfa4ae4a7ed882cdc2fef0cd"
  license "Apache-2.0"

  bottle do
    root_url "https://github.com/astanabe/ikafssn/releases/download/v0.1.2026.10.27"
    sha256 cellar: :any, arm64_tahoe: "104d75cd107fd8703754adf2d8defae2007025f3d71ccea20d2d0cda09c68166"
  end

  depends_on "cmake" => :build
  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "curl"
  depends_on "jsoncpp"
  depends_on "libdeflate"
  depends_on "lmdb"
  depends_on "openssl@3"
  depends_on "sqlite"
  depends_on "tbb"
  # Compressed I/O codecs for FASTA queries and TSV/JSON/FASTA output.
  # zlib and bzip2 ship with macOS so are not separately declared; xz
  # provides liblzma; zstd is required project-wide as of v0.1.2026.05.05.
  depends_on "xz"
  depends_on "zstd"

  resource "ncbi-cxx-toolkit" do
    url "https://github.com/ncbi/ncbi-cxx-toolkit-public/archive/refs/tags/release/30.8.0.tar.gz"
    sha256 "0df68f90abe6a48ad8927cf8dca5888a11a520bf8855f1621a4a5d27839a2769"
  end

  resource "parasail" do
    url "https://github.com/jeffdaily/parasail/archive/refs/tags/v2.6.2.tar.gz"
    sha256 "9057041db8e1cde76678f649420b85054650414e5de9ea84ee268756c7ea4b4b"
  end

  resource "htslib" do
    url "https://github.com/samtools/htslib/releases/download/1.25/htslib-1.25.tar.bz2"
    sha256 "158c271e4e2986bb2dd11283b640edc10c56695b293df77a109ce99480303730"
  end

  resource "drogon" do
    url "https://github.com/drogonframework/drogon/archive/refs/tags/v1.9.14.tar.gz"
    sha256 "3831bfae74eb6b47965a424e5c9d593d5efa31e9f7e6a5e02d4754039facff5e"
  end

  # The Drogon release tarball does not include the trantor submodule contents;
  # this is the matching trantor release tag.
  resource "trantor" do
    url "https://github.com/an-tao/trantor/archive/refs/tags/v1.5.29.tar.gz"
    sha256 "0e6b9cc32720cbca61ac2e04d4d9b8e1afac3f4007b5978a91461d3eb21d653b"
  end

  def install
    # Build Parasail (static, patched for DEGMATCH matrix and score-based CIGAR match)
    resource("parasail").stage do
      system "patch", "-p1", "-i", "#{buildpath}/patches/parasail-degmatch-cigar-score.patch"
      system "cmake", "-S", ".", "-B", "build",
             "-DCMAKE_BUILD_TYPE=Release",
             "-DCMAKE_INSTALL_PREFIX=#{buildpath}/parasail",
             "-DBUILD_SHARED_LIBS=OFF",
             "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
      system "cmake", "--build", "build", "-j#{ENV.make_jobs}"
      system "cmake", "--install", "build"
    end

    # Build htslib (static)
    resource("htslib").stage do
      system "autoreconf", "-i"
      system "./configure",
             "--prefix=#{buildpath}/htslib",
             "--disable-libcurl", "--disable-gcs", "--disable-s3",
             "CPPFLAGS=-I#{HOMEBREW_PREFIX}/include",
             "LDFLAGS=-L#{HOMEBREW_PREFIX}/lib"
      system "make", "-j#{ENV.make_jobs}"
      system "make", "install"
    end

    # Build NCBI C++ Toolkit (static)
    resource("ncbi-cxx-toolkit").stage do
      ENV.prepend "CFLAGS", "-I#{HOMEBREW_PREFIX}/include"
      ENV.prepend "CXXFLAGS", "-I#{HOMEBREW_PREFIX}/include"
      system "./cmake-configure",
             "--without-debug",
             "--with-projects=objtools/blast/seqdb_reader;objtools/blast/blastdb_format",
             "--with-install=#{buildpath}/ncbi-cxx-toolkit"
      cd Dir["CMake-*/build"].first do
        system "make", "-j#{ENV.make_jobs}"
        system "make", "install"
      end
    end

    # Detect NCBI build tag
    ncbi_build_tag = Dir["#{buildpath}/ncbi-cxx-toolkit/CMake-*/"].map { |d| File.basename(d) }.first

    # Build Drogon (static; trantor submodule replaced by the matching release tarball)
    resource("drogon").stage do
      drogon_src = Pathname.pwd
      rm_r drogon_src/"trantor"
      (drogon_src/"trantor").mkpath
      resource("trantor").stage(drogon_src/"trantor")

      system "cmake", "-S", ".", "-B", "build",
             "-DCMAKE_BUILD_TYPE=Release",
             "-DCMAKE_INSTALL_PREFIX=#{buildpath}/drogon",
             "-DOPENSSL_ROOT_DIR=#{Formula["openssl@3"].opt_prefix}",
             "-DBUILD_SHARED_LIBS=OFF",
             "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
             "-DBUILD_CTL=OFF",
             "-DBUILD_EXAMPLES=OFF",
             "-DBUILD_ORM=OFF",
             "-DBUILD_BROTLI=OFF",
             "-DBUILD_YAML_CONFIG=OFF",
             "-DBUILD_DOC=OFF"
      system "cmake", "--build", "build", "-j#{ENV.make_jobs}"
      system "cmake", "--install", "build"
    end

    # Build ikafssn
    system "cmake", "-S", ".", "-B", "build",
           "-DCMAKE_BUILD_TYPE=Release",
           "-DNCBI_TOOLKIT_BUILD_TAG=#{ncbi_build_tag}",
           "-DDROGON_DIR=#{buildpath}/drogon",
           "-DBUILD_HTTPD=ON",
           *std_cmake_args
    system "cmake", "--build", "build", "-j#{ENV.make_jobs}"
    system "cmake", "--install", "build"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ikafssnindex --version 2>&1")
  end
end
